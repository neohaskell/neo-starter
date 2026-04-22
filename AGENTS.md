# NEOHASKELL STARTER — KNOWLEDGE BASE

This file is for AI assistants and future engineers working on this project.
It captures conventions that are not obvious from reading the code.

## OVERVIEW

Event-sourced CQRS application using Event Modeling vocabulary:

- **Commands** (blue) — user intentions. Files under `Commands/`.
- **Events** (orange) — facts that happened. One record per file under `Events/`, combined into a sum type in `Event.hs`.
- **Queries / read models** (green) — projected views. Files under `Queries/`.
- **Integrations** (yellow) — cross-domain coordination. Files in `Integrations.hs` (none yet in this starter).

## PROJECT STRUCTURE

```
neohaskell-starter/
├── launcher/Launcher.hs                   # Thin entry point
├── src/
│   ├── App.hs                             # All service composition
│   ├── Starter/Config.hs                  # Typed configuration (defineConfig)
│   └── Starter/Counter/                   # Example bounded context — delete or rename
│       ├── Core.hs                        # Re-exports Entity + Event
│       ├── Entity.hs                      # CounterEntity + update
│       ├── Event.hs                       # CounterEvent sum type
│       ├── Service.hs                     # Service.new |> command @...
│       ├── Events/                        # One file per event
│       │   ├── CounterCreated.hs
│       │   ├── CounterIncremented.hs
│       │   └── CounterDecremented.hs
│       ├── Commands/                      # One file per command
│       │   ├── CreateCounter.hs
│       │   ├── IncrementCounter.hs
│       │   └── DecrementCounter.hs
│       └── Queries/
│           └── CounterView.hs
└── tests/
    ├── integration/smoke.hurl
    └── scenarios/counter-flow.hurl
```

### Hard rules

1. **One event per file** under `Events/`. The sum type in `Event.hs` wraps them. This scales — do not collapse multiple events into one file.
2. **One command per file** under `Commands/`.
3. **`Core.hs` re-exports** `Entity` and `Event`. Import it from inside the bounded context.
4. **Service, Entity, Event, Core** live directly in the context directory.
5. **Queries** go under `Queries/`, each with its own file.

## TASK WORKFLOW

When adding a feature, follow this order:

1. Design the event(s) first (orange) — write the `Events/*.hs` file(s).
2. Add the new variants to `Event.hs` sum type + `getEventEntityId`.
3. Extend `Entity.hs` — new fields (if needed) + new cases in `update`.
4. Write the `Commands/*.hs` file — `decide` function contains the business logic.
5. Register the command in `Service.hs`.
6. If a new read model is needed, add `Queries/YourView.hs` and wire it in `App.hs` with `withQuery`.
7. Add Hurl tests in `tests/commands/` or `tests/scenarios/`.

## CODEBASE PATTERNS

### Event record (Events/YourEvent.hs)

```haskell
module Starter.Counter.Events.CounterCreated (Event (..)) where

import Core
import Json qualified


data Event = Event
  { entityId :: Uuid
  , label :: Text
  }
  deriving (Generic, Show)


instance Json.FromJSON Event
instance Json.ToJSON Event
```

Every event record MUST carry `entityId :: Uuid` so the stream can be keyed.

### Event sum type (Event.hs)

```haskell
data CounterEvent
  = CounterCreated CounterCreated.Event
  | CounterIncremented CounterIncremented.Event
  | CounterDecremented CounterDecremented.Event
  deriving (Generic, Show)


getEventEntityId :: CounterEvent -> Uuid
getEventEntityId event = case event of
  CounterCreated e -> e.entityId
  CounterIncremented e -> e.entityId
  CounterDecremented e -> e.entityId
```

### Entity (Entity.hs)

```haskell
data CounterEntity = CounterEntity
  { counterId :: Uuid
  , label :: Text
  , value :: Int
  }
  deriving (Generic)


instance Default CounterEntity where def = initialState


type instance NameOf CounterEntity = "CounterEntity"
type instance EventOf CounterEntity = CounterEvent
type instance EntityOf CounterEvent = CounterEntity


instance Entity CounterEntity where
  initialStateImpl = initialState
  updateImpl = update


update :: CounterEvent -> CounterEntity -> CounterEntity
update event entity = case event of
  CounterCreated e ->
    CounterEntity { counterId = e.entityId, label = e.label, value = 0 }
  CounterIncremented e ->
    entity { value = entity.value + e.amount }
  CounterDecremented e ->
    entity { value = entity.value - e.amount }
```

### Creation command (Commands/CreateX.hs)

```haskell
data CreateCounter = CreateCounter { label :: Text }
  deriving (Generic, Typeable, Show)


instance Json.FromJSON CreateCounter


getEntityId :: CreateCounter -> Maybe Uuid
getEntityId _ = Nothing                                   -- creation → no prior entity


decide :: CreateCounter -> Maybe CounterEntity -> RequestContext -> Decision CounterEvent
decide cmd entity _ctx = case entity of
  Just _ ->
    Decider.reject "Counter already exists"
  Nothing ->
    if cmd.label == ""
      then Decider.reject "Label cannot be empty"
      else do
        newId <- Decider.generateUuid
        Decider.acceptNew
          [ CounterCreated CounterCreated.Event { entityId = newId, label = cmd.label } ]


type instance EntityOf CreateCounter = CounterEntity
type instance TransportsOf CreateCounter = '[WebTransport]


command ''CreateCounter
```

### Update command (Commands/UpdateX.hs)

```haskell
getEntityId :: IncrementCounter -> Maybe Uuid
getEntityId cmd = Just cmd.entityId                       -- update → load existing


decide :: IncrementCounter -> Maybe CounterEntity -> RequestContext -> Decision CounterEvent
decide cmd entity _ctx = case entity of
  Nothing -> Decider.reject "Counter not found"
  Just existing ->
    Decider.acceptExisting
      [ CounterIncremented CounterIncremented.Event
          { entityId = existing.counterId, amount = cmd.amount }
      ]
```

### Decider functions — quick reference

| Situation                   | Call                                  |
|-----------------------------|---------------------------------------|
| Creation (no existing)      | `Decider.acceptNew [events]`          |
| Update (existing required)  | `Decider.acceptExisting [events]`     |
| Optimistic concurrency      | `Decider.acceptAfter pos [events]`    |
| Business rule violation     | `Decider.reject "reason"`             |
| Need a fresh UUID in decide | `id <- Decider.generateUuid`          |

### Query / read model (Queries/YourView.hs)

```haskell
{-# LANGUAGE TemplateHaskell #-}

data CounterView = CounterView
  { counterId :: Uuid
  , label :: Text
  , value :: Int
  }
  deriving (Eq, Show, Generic)


canAccess :: Maybe UserClaims -> Maybe QueryAuthError
canAccess = publicAccess


canView :: Maybe UserClaims -> CounterView -> Maybe QueryAuthError
canView = publicView


deriveQuery ''CounterView [''CounterEntity]


instance QueryOf CounterEntity CounterView where
  queryId entity = entity.counterId
  combine entity _maybeExisting =
    Update CounterView
      { counterId = entity.counterId
      , label = entity.label
      , value = entity.value
      }
```

### Service (Service.hs)

```haskell
service :: Service _ _
service =
  Service.new
    |> Service.command @CreateCounter
    |> Service.command @IncrementCounter
    |> Service.command @DecrementCounter
```

All commands registered here MUST share the same `EntityOf` + `EventOf`. The compiler enforces this.

### App wiring (App.hs)

```haskell
app :: Application
app =
  Application.new
    |> Application.withConfig @StarterConfig
    |> Application.withEventStore (\(_ :: StarterConfig) -> InMemory.new)
    |> Application.withTransport WebTransport.server
    |> Application.withService Counter.service
    |> Application.withQuery @CounterView
```

## NEOHASKELL STYLE (MANDATORY)

| Rule                  | Correct                   | Incorrect                 |
|-----------------------|---------------------------|---------------------------|
| Pipe operator         | `x \|> foo \|> bar`       | `bar $ foo x`, `bar . foo` |
| Bindings              | `do` + `let`              | `let..in`, `where`        |
| Pattern match         | `case x of`               | Function head patterns    |
| Yield (Task)          | `Task.yield value`        | `pure`, `return`          |
| Error type            | `Result err ok`           | `Either a b`              |
| String concatenation  | `[fmt\|hello {name}!\|]`  | `"h" <> name`, `++`       |
| Effects               | `Task err val`            | Raw `IO a`                |
| Imports               | Qualified per module      | Bare imports              |
| Base imports          | `import Data.X qualified as GhcX` | `import Data.X`  |

## HURL TEST PATTERNS

```hurl
POST http://localhost:8080/commands/create-counter
{ "label": "test" }
HTTP 200
[Asserts]
jsonpath "$.entityId" matches /^[0-9a-f-]{36}$/
```

Query tests use `[Options] retry: 10 retry-interval: 200` to wait for projections to catch up.

## ANTI-PATTERNS (FORBIDDEN)

- `let..in` or `where` clauses inside `do`/function bodies
- Pattern matching in function definition heads
- Point-free style
- Single-letter type parameters (`a`, `b`, `m`)
- `pure` / `return` — use `Task.yield`
- Raw `IO a` — use `Task err val`
- `Either` — use `Result`
- `++` / `<>` for strings — use `[fmt|...|]`
- Importing from `base` without `Ghc` prefix
- Multi-paragraph docstrings (one short line max)

## REFERENCE

Deeper material under `.skills/`:

- `.skills/neohaskell-eventsourcing/SKILL.md` — full event-sourcing implementation templates.
- `.skills/neohaskell-reference/SKILL.md` — `nhcore` API cheat sheet (Array, Task, Text, Map).
- `.skills/event-modeling-parser/SKILL.md` — converting Event Modeling diagrams into implementation specs.

Canonical docs: https://neohaskell.org
