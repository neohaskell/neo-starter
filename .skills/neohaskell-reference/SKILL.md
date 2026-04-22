# NeoHaskell Core Library Reference Skill

Use nhcore functions correctly. Do NOT use base or standard Haskell libraries.

## TRIGGER PHRASES

- "length not in scope"
- "sum not in scope"
- "div not in scope"
- "NoChange doesn't exist"
- "how do I sum an array"
- "what's the NeoHaskell way to..."
- "function not found"
- "cannot find module Data."
- Using any `base` or `Data.*` imports

## QUICK REFERENCE: Haskell → NeoHaskell

| Standard Haskell | NeoHaskell | Notes |
|------------------|------------|-------|
| `IO a` | `Task err val` | Use `Task.yield` not `pure`/`return` |
| `Either a b` | `Result err val` | `Result.Ok`, `Result.Err` |
| `pure x` / `return x` | `Task.yield x` | NEVER use `pure`/`return` |
| `length xs` | `Array.length xs` | Qualified, type-specific |
| `sum xs` | `Array.sumIntegers xs` | Int-only! Or `Array.reduce (+) 0` |
| `div a b` | `a // b` | Integer division operator |
| `<>` | `++` | Appendable typeclass |
| `"a" <> "b"` | `[fmt\|{a}{b}\|]` | Prefer string interpolation |
| `filter p xs` | `Array.takeIf p xs` | Keep elements matching predicate |
| `filterNot` | `Array.dropIf` | Remove elements matching predicate |
| `let x = y in z` | `do { let x = y; z }` | No `let..in` or `where` |
| `fmap f xs` | `Array.map f xs` | Qualified per type |
| `Data.Text` | `Text` | Re-exported |
| `Data.Map` | `Map` | Re-exported |
| `Data.Vector` | `Array` | Vector-backed |
| `NoChange` | `NoOp` | QueryAction constructor |

## FULL REFERENCE

For complete API documentation, fetch from GitHub:

```
https://raw.githubusercontent.com/neohaskell/neohaskell/main/core/REFERENCE.md
```

Use `webfetch` or `librarian` agent to retrieve the full reference when needed.

## COMMON FUNCTIONS BY MODULE

### Array (most common)
```haskell
Array.length    :: Array a -> Int
Array.isEmpty   :: Array a -> Bool
Array.map       :: (a -> b) -> Array a -> Array b
Array.takeIf    :: (a -> Bool) -> Array a -> Array a  -- filter
Array.dropIf    :: (a -> Bool) -> Array a -> Array a  -- filterNot
Array.reduce    :: (a -> b -> b) -> b -> Array a -> b -- foldr
Array.foldl     :: (a -> b -> b) -> b -> Array a -> b
Array.sumIntegers :: Array Int -> Int                 -- Int only!
Array.first     :: Array a -> Maybe a
Array.last      :: Array a -> Maybe a
Array.get       :: Int -> Array a -> Maybe a
Array.find      :: (a -> Bool) -> Array a -> Maybe a
Array.any       :: (a -> Bool) -> Array a -> Bool
Array.flatten   :: Array (Array a) -> Array a
Array.zip       :: Array b -> Array a -> Array (a, b)
```

### Task
```haskell
Task.yield      :: value -> Task _ value              -- NOT pure/return!
Task.throw      :: err -> Task err _
Task.map        :: (a -> b) -> Task e a -> Task e b
Task.mapError   :: (e1 -> e2) -> Task e1 a -> Task e2 a
Task.andThen    :: (a -> Task e b) -> Task e a -> Task e b
Task.fromIO     :: IO a -> Task _ a
Task.runOrPanic :: Show e => Task e a -> IO a
Task.forEach    :: (a -> Task e ()) -> Array a -> Task e ()
Task.when       :: Bool -> Task e () -> Task e ()
Task.unless     :: Bool -> Task e () -> Task e ()
```

### Text
```haskell
Text.length     :: Text -> Int
Text.isEmpty    :: Text -> Bool
Text.split      :: Text -> Text -> Array Text
Text.joinWith   :: Text -> Array Text -> Text
Text.contains   :: Text -> Text -> Bool
Text.toInt      :: Text -> Maybe Int
Text.fromInt    :: Int -> Text
```

### Map
```haskell
Map.get         :: Ord k => k -> Map k v -> Maybe v
Map.set         :: Ord k => k -> v -> Map k v -> Map k v
Map.contains    :: Ord k => k -> Map k v -> Bool
Map.keys        :: Map k v -> Array k
Map.values      :: Map k v -> Array v
Map.length      :: Map k v -> Int
```

### QueryAction (Event Sourcing)
```haskell
data QueryAction query
  = Update query  -- Store/update the query instance
  | Delete        -- Remove from store  
  | NoOp          -- Take no action (NOT NoChange!)
```

## IMPORT STYLE

Always use NeoHaskell import pattern:

```haskell
-- Import type unqualified, module qualified
import Array (Array)
import Array qualified

import Text (Text)
import Text qualified

import Task (Task)
import Task qualified
```

For unavoidable base imports, prefix with `Ghc`:

```haskell
import Data.List qualified as GhcList
```

## WHAT TO DO WHEN SOMETHING IS MISSING

If you need a function that doesn't exist in nhcore:

1. **DO NOT** import from `base`, `containers`, `text`, `bytestring`
2. **DO NOT** create workarounds using raw GHC primitives
3. **DO** create a GitHub issue at: `github.com/neohaskell/neohaskell/issues`

### Issue Template

```markdown
**Title:** [nhcore] Add `functionName` to `ModuleName`

**Description:**
I need a function to [description].

**Proposed API:**
functionName :: InputType -> OutputType

**Use case:**
[Why needed]

**Haskell equivalent:**
[Standard function if exists]
```

## STYLE RULES (MANDATORY)

- Use `|>` pipe operator, NOT `$` nesting
- Use `do` + `let` bindings, NOT `let..in` or `where`
- Pattern match ONLY in `case..of`, not function definitions
- Use `Task.yield`, NEVER `pure` or `return`
- Use `Result`, NEVER `Either`
- Use `[fmt|...|]` for string interpolation, not `++` or `<>`
- Qualified imports with full module name
- Descriptive type parameters (`value`, `element`), not (`a`, `b`)
