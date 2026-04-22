# NeoHaskell Event Sourcing Implementation Skill

Implement event-sourced bounded contexts in NeoHaskell following established patterns from nhcore.

## TRIGGER PHRASES

- "Implement this slice"
- "Create this command"
- "Add this entity"
- "Build this query"
- "Wire this integration"
- "Implement event sourcing"

## IMPLEMENTATION WORKFLOW

### Step 1: Read the Slice Specification

```bash
# Check PRD for next slice
cat slices/index.json | jq '.slices[] | select(.status == "Planned") | .folder' | head -1

# Read slice details
cat slices/Context/slice-name/slice.json
```

### Step 2: Implement in Order

1. **Core.hs** - Entity + Events + update function
2. **Commands/*.hs** - Command handlers with decide logic
3. **Service.hs** - Register commands
4. **Queries/*.hs** - Read model projections (if needed)
5. **Integrations.hs** - Cross-domain coordination (if needed)
6. **App.hs** - Wire everything together
7. **tests/*.hurl** - Blackbox acceptance tests

## CODE TEMPLATES

### Entity Template (Core.hs)

```haskell
module MyApp.Domain.Core (
  DomainEntity (..),
  DomainEvent (..),
  EntityCreatedEvent (..),
  FieldUpdatedEvent (..),
  initialState,
) where

import Array qualified
import Core
import Json qualified
import Service.Command.Core (Event (..))
import Uuid qualified


-- | Entity: Current state of the aggregate
data DomainEntity = DomainEntity
  { entityId :: Uuid
  , fieldName :: Text
  -- Add fields from slice specification
  }
  deriving (Generic)


instance Json.FromJSON DomainEntity


instance Json.ToJSON DomainEntity


instance Default DomainEntity where
  def = initialState


initialState :: DomainEntity
initialState =
  DomainEntity
    { entityId = Uuid.nil
    , fieldName = ""
    }


type instance NameOf DomainEntity = "DomainEntity"


instance Entity DomainEntity where
  initialStateImpl = initialState
  updateImpl = update


-- | Event Records: Each event is a separate record type
data EntityCreatedEvent = EntityCreatedEvent
  { entityId :: Uuid
  , fieldName :: Text
  }
  deriving (Generic)


instance Json.FromJSON EntityCreatedEvent


instance Json.ToJSON EntityCreatedEvent


data FieldUpdatedEvent = FieldUpdatedEvent
  { entityId :: Uuid
  , newValue :: Text
  }
  deriving (Generic)


instance Json.FromJSON FieldUpdatedEvent


instance Json.ToJSON FieldUpdatedEvent


-- | Event Sum Type: Wraps all event records
data DomainEvent
  = EntityCreated EntityCreatedEvent
  | FieldUpdated FieldUpdatedEvent
  deriving (Generic)


getEventEntityId :: DomainEvent -> Uuid
getEventEntityId event = case event of
  EntityCreated e -> e.entityId
  FieldUpdated e -> e.entityId


type instance EventOf DomainEntity = DomainEvent


type instance EntityOf DomainEvent = DomainEntity


instance Event DomainEvent where
  getEventEntityIdImpl = getEventEntityId


instance Json.FromJSON DomainEvent


instance Json.ToJSON DomainEvent


-- | Update: Apply event to entity state
update :: DomainEvent -> DomainEntity -> DomainEntity
update event entity = case event of
  EntityCreated e ->
    DomainEntity
      { entityId = e.entityId
      , fieldName = e.fieldName
      }
  FieldUpdated e ->
    entity { fieldName = e.newValue }
```

### Create Command Template

```haskell
module MyApp.Domain.Commands.CreateDomain (
  CreateDomain (..),
  getEntityId,
  decide,
) where

import Core
import Decider qualified
import Json qualified
import Service.Auth (RequestContext (..))
import Service.Command.Core (TransportOf)
import Service.CommandExecutor.TH (command)
import Service.Transport.Web (WebTransport)
import MyApp.Domain.Core


data CreateDomain = CreateDomain
  { fieldName :: Text
  }
  deriving (Generic, Typeable, Show)


instance Json.FromJSON CreateDomain


getEntityId :: CreateDomain -> Maybe Uuid
getEntityId _ = Nothing


decide :: CreateDomain -> Maybe DomainEntity -> RequestContext -> Decision DomainEvent
decide cmd entity _ctx = case entity of
  Just _ ->
    Decider.reject "Entity already exists!"
  Nothing -> do
    -- Validation
    if cmd.fieldName == ""
      then Decider.reject "Field name cannot be empty"
      else do
        id <- Decider.generateUuid
        Decider.acceptNew
          [ EntityCreated EntityCreatedEvent
              { entityId = id
              , fieldName = cmd.fieldName
              }
          ]


type instance EntityOf CreateDomain = DomainEntity


type instance TransportOf CreateDomain = WebTransport


command ''CreateDomain
```

### Update Command Template

```haskell
module MyApp.Domain.Commands.UpdateField (
  UpdateField (..),
  getEntityId,
  decide,
) where

import Core
import Decider qualified
import Json qualified
import Service.Auth (RequestContext)
import Service.Command.Core (TransportOf)
import Service.CommandExecutor.TH (command)
import Service.Transport.Web (WebTransport)
import MyApp.Domain.Core


data UpdateField = UpdateField
  { targetId :: Uuid
  , newValue :: Text
  }
  deriving (Generic, Typeable, Show)


instance Json.FromJSON UpdateField


getEntityId :: UpdateField -> Maybe Uuid
getEntityId cmd = Just cmd.targetId


decide :: UpdateField -> Maybe DomainEntity -> RequestContext -> Decision DomainEvent
decide cmd entity _ctx = case entity of
  Nothing ->
    Decider.reject "Entity not found!"
  Just existing -> do
    -- Validation
    if cmd.newValue == ""
      then Decider.reject "Value cannot be empty"
      else
        Decider.acceptExisting
          [ FieldUpdated FieldUpdatedEvent
              { entityId = existing.entityId
              , newValue = cmd.newValue
              }
          ]


type instance EntityOf UpdateField = DomainEntity


type instance TransportOf UpdateField = WebTransport


command ''UpdateField
```

### Service Template

```haskell
module MyApp.Domain.Service (service) where

import Core
import Service qualified
import MyApp.Domain.Commands.CreateDomain (CreateDomain)
import MyApp.Domain.Commands.UpdateField (UpdateField)
import MyApp.Domain.Core ()


service :: Service _ _
service =
  Service.new
    |> Service.command @CreateDomain
    |> Service.command @UpdateField
```

### Query Template

```haskell
{-# LANGUAGE TemplateHaskell #-}

module MyApp.Domain.Queries.DomainSummary (
  DomainSummary (..),
  canAccess,
  canView,
) where

import Core
import Json qualified
import Service.Query.Auth (QueryAuthError, UserClaims, publicAccess, publicView)
import Service.Query.TH (deriveQuery)
import MyApp.Domain.Core (DomainEntity (..))


data DomainSummary = DomainSummary
  { summaryId :: Uuid
  , fieldName :: Text
  , lastUpdated :: Maybe Int64
  }
  deriving (Eq, Show, Generic)


instance Json.ToJSON DomainSummary


instance Json.FromJSON DomainSummary


canAccess :: Maybe UserClaims -> Maybe QueryAuthError
canAccess = publicAccess


canView :: Maybe UserClaims -> DomainSummary -> Maybe QueryAuthError
canView = publicView


deriveQuery ''DomainSummary [''DomainEntity]


instance QueryOf DomainEntity DomainSummary where
  queryId entity = entity.entityId

  combine entity _maybeExisting =
    Update DomainSummary
      { summaryId = entity.entityId
      , fieldName = entity.fieldName
      , lastUpdated = Nothing
      }
```

### Outbound Integration Template

```haskell
module MyApp.Domain.Integrations (domainIntegrations) where

import Integration qualified
import Integration.Command qualified as Command
import MyApp.Domain.Core (DomainEntity (..), DomainEvent (..))
import MyApp.OtherDomain.Commands.Notify (Notify (..))


domainIntegrations :: DomainEntity -> DomainEvent -> Integration.Outbound
domainIntegrations entity event = case event of
  EntityCreated {} -> Integration.none
  FieldUpdated {newValue} -> Integration.batch
    [ Integration.outbound Command.Emit
        { command = Notify
            { targetId = entity.entityId
            , message = newValue
            }
        }
    ]
```

### App Wiring Template

```haskell
-- In App.hs, add:
import MyApp.Domain.Core (DomainEntity)
import MyApp.Domain.Integrations (domainIntegrations)
import MyApp.Domain.Queries.DomainSummary (DomainSummary)
import MyApp.Domain.Service qualified as Domain

-- In application builder:
app =
  Application.new
    |> Application.withEventStore postgresConfig
    |> Application.withTransport WebTransport.server
    |> Application.withService Domain.service
    |> Application.withQuery @DomainSummary
    |> Application.withOutbound @DomainEntity domainIntegrations
```

### Hurl Test Template

```hurl
# Create Entity - Success
POST http://localhost:8080/commands/create-domain
{"fieldName": "test value"}

HTTP/1.1 200
[Asserts]
jsonpath "$.entityId" exists
jsonpath "$.entityId" matches /^[0-9a-f-]{36}$/

[Captures]
entity_id: jsonpath "$.entityId"


# Create Entity - Validation Error
POST http://localhost:8080/commands/create-domain
{"fieldName": ""}

HTTP/1.1 400
[Asserts]
jsonpath "$.error" contains "empty"


# Query Read Model
GET http://localhost:8080/queries/domain-summary
[Options]
retry: 5
retry-interval: 200

HTTP/1.1 200
[Asserts]
jsonpath "$" isCollection
jsonpath "$[?(@.summaryId == '{{entity_id}}')].fieldName" nth 0 == "test value"
```

## DECISION PATTERNS

### When to use which Decider function:

| Scenario | Function | Description |
|----------|----------|-------------|
| Creating new entity | `Decider.acceptNew [events]` | Entity must NOT exist |
| Updating existing | `Decider.acceptExisting [events]` | Entity MUST exist |
| Optimistic concurrency | `Decider.acceptAfter position [events]` | Check stream position |
| Validation failure | `Decider.reject "reason"` | Reject with message |
| Generate ID | `Decider.generateUuid` | Create new UUID in Decision monad |

### getEntityId patterns:

| Command Type | Return | Example |
|--------------|--------|---------|
| Create | `Nothing` | New entity, ID generated in decide |
| Update/Delete | `Just cmd.entityId` | Target existing entity |
| Idempotent create | `Just cmd.entityId` | Client provides ID |

## NEOHASKELL STYLE CHECKLIST

Before committing, verify:

- [ ] Using `|>` pipe operator (not `$` nesting)
- [ ] Using `do` + `let` bindings (not `let..in` or `where`)
- [ ] Pattern matching only in `case..of` (not function definitions)
- [ ] Using `Task.yield` (not `pure` or `return`)
- [ ] Using `Result` (not `Either`)
- [ ] Using `[fmt|...|]` for string interpolation
- [ ] Qualified imports with full module name suffix
- [ ] Descriptive type parameters (not single letters)

## VERIFICATION

After implementing a slice:

```bash
# Build
cabal build all

# Check for errors
hlint src/

# Start app (in separate terminal)
docker-compose up -d
cabal run my-app &

# Run tests
hurl --test tests/commands/new-command.hurl
hurl --test tests/scenarios/new-scenario.hurl

# Stop app
kill %1
```

## UPDATE PROGRESS

After successful implementation:

1. Update slice status in `slices/index.json`:
   ```json
   {"id": "slice-id", "status": "Done", ...}
   ```

2. Add iteration log to `progress.txt`:
   ```
   ## [YYYY-MM-DD HH:MM] - Slice Name
   
   ### What was implemented
   - ...
   
   ### Files changed
   - ...
   
   ### Test Results
   - ...
   
   ### Learnings
   - ...
   ```

3. Update `AGENTS.md` Learnings section with new patterns discovered

## COMMON GOTCHAS

| Issue | Solution |
|-------|----------|
| `NameOf` not found | Add `type instance NameOf X = "X"` |
| Entity not updating | Check `updateImpl` handles all event cases |
| Query not updating | Verify `QueryOf` instance and `deriveQuery` entities list |
| Command not found | Register in Service.hs with `Service.command @Type` |
| Integration not firing | Register with `Application.withOutbound @Entity` |
| Tests timing out | Add `retry` and `retry-interval` options |
