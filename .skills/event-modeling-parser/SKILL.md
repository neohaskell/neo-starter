# Event Modeling Parser Skill

Parse Event Modeling diagrams and convert them to implementation specifications for NeoHaskell event-sourced applications.

## TRIGGER PHRASES

- "Parse this event model"
- "Convert this diagram to specs"
- "Analyze this event modeling diagram"
- "Extract slices from this diagram"
- "Generate specifications from event model"

## EVENT MODELING VISUAL LANGUAGE

### Color Coding

| Color | Element | NeoHaskell Equivalent |
|-------|---------|----------------------|
| **Blue** | Command | `Commands/*.hs` - User intention, `decide` function |
| **Orange** | Event | `Core.hs` - Domain event, facts that happened |
| **Green** | Read Model / Query | `Queries/*.hs` - Projected view, `QueryOf` instance |
| **Yellow** | Integration / Automation | `Integrations.hs` - Cross-domain coordination |
| **White/UI** | User Interface | External - not generated |

### Swimlanes (Horizontal Lanes)

Swimlanes represent **Bounded Contexts** or **Entities**. Each swimlane becomes:
- A directory under `src/MyApp/`
- An entity type in `Core.hs`
- A service in `Service.hs`

### Reading the Diagram (Left to Right)

1. **Commands** (blue) trigger the flow
2. **Events** (orange) are emitted by commands
3. **Read Models** (green) project current state from events
4. **Integrations** (yellow) react to events and trigger other commands

### Arrows

- **Command → Event**: The command's `decide` function produces these events
- **Event → Read Model**: The read model subscribes to these events via `QueryOf`
- **Event → Integration**: The integration reacts to these events
- **Integration → Command**: The integration emits this command to another service

## PARSING PROCEDURE

### Step 1: Identify Swimlanes (Entities)

For each horizontal swimlane:
```
Swimlane: "Proposal"
→ Entity: ProposalEntity
→ Directory: src/MyApp/Proposal/
→ Events: All orange boxes in this lane
```

### Step 2: Extract Commands (Blue Boxes)

For each blue box:
```
Command: "UploadProposalPdf"
Fields: file:PdfFile, userId:UUID
→ File: src/MyApp/Proposal/Commands/UploadProposalPdf.hs
→ getEntityId: Determine from fields (proposalId → Just, otherwise Nothing)
→ decide: Business logic based on position in flow
```

### Step 3: Extract Events (Orange Boxes)

For each orange box:
```
Event: "ProposalPdfUploaded"
Fields: file:FileRef, userId:UUID, uploadDate:DateTime, proposalId:UUID
→ Add to Core.hs DomainEvent sum type
→ Add case to getEventEntityId (extract entityId/proposalId)
→ Add case to update function
```

### Step 4: Extract Read Models (Green Boxes)

For each green box:
```
Query: "EvaluatedProposal"
Fields: proposalId:UUID, scores:ListOfMetricScore, fundingRecommendation:Text
→ File: src/MyApp/Proposal/Queries/EvaluatedProposal.hs
→ deriveQuery with source entities
→ QueryOf instance with combine logic
```

### Step 5: Extract Integrations (Yellow Boxes + Arrows)

For each yellow box or automation arrow:
```
Integration: "TranscribePdf" (yellow, triggered by ProposalPdfUploaded)
Emits: TranscribePdf command
→ Add to Integrations.hs
→ Pattern match on triggering event
→ Use Integration.outbound Command.Emit
```

### Step 6: Identify Slices

A **slice** is a vertical cut through the diagram representing one complete feature:

```
Slice: "Upload Proposal"
- Command: UploadProposalPdf
- Event: ProposalPdfUploaded
- Integration: Triggers TranscribePdf
- Test: POST /commands/upload-proposal-pdf
```

## OUTPUT FORMAT

### Slice Specification (JSON)

```json
{
  "id": "upload-proposal",
  "name": "Upload Proposal",
  "context": "Proposal",
  "status": "Planned",
  "command": {
    "name": "UploadProposalPdf",
    "fields": [
      {"name": "file", "type": "PdfFile"},
      {"name": "userId", "type": "Uuid"}
    ],
    "createsEntity": true
  },
  "events": [
    {
      "name": "ProposalPdfUploaded",
      "fields": [
        {"name": "entityId", "type": "Uuid"},
        {"name": "file", "type": "FileRef"},
        {"name": "userId", "type": "Uuid"},
        {"name": "uploadDate", "type": "DateTime"}
      ]
    }
  ],
  "integrations": [
    {
      "trigger": "ProposalPdfUploaded",
      "emits": "TranscribePdf",
      "type": "outbound"
    }
  ],
  "queries": [],
  "tests": [
    {
      "type": "command",
      "endpoint": "/commands/upload-proposal-pdf",
      "method": "POST",
      "assertions": ["entityId exists"]
    }
  ]
}
```

### Slice Specification (Markdown)

```markdown
# Slice: Upload Proposal

## Context
Proposal

## Command
**UploadProposalPdf**
- file: PdfFile
- userId: Uuid
- Creates new entity: Yes

## Events Produced
**ProposalPdfUploaded**
- entityId: Uuid
- file: FileRef
- userId: Uuid
- uploadDate: DateTime

## Integrations
- On `ProposalPdfUploaded` → Emit `TranscribePdf` command

## Acceptance Criteria
- [ ] POST /commands/upload-proposal-pdf returns 200
- [ ] Response contains entityId (UUID format)
- [ ] ProposalPdfUploaded event is stored
- [ ] TranscribePdf command is triggered
```

## EXAMPLE: PARSING THE PROPOSAL EVALUATION FLOW

Given diagram with:
- Swimlanes: Proposal, Proposal Metric Evaluation
- Blue: UploadProposalPdf, TranscribePdf, FillMarkdownTemplate, TriggerEvaluation, EvaluateMetric, GenerateRecommendation
- Orange: ProposalPdfUploaded, ProposalPdfTranscribed, ProposalMarkdownTemplateFilled, MetricEvaluationStarted, ProposalMetricEvaluated, ProposalRecommendationGenerated
- Green: ProposalMarkdown, EvaluatedProposal

### Extracted Slices:

1. **upload-proposal** - UploadProposalPdf → ProposalPdfUploaded → triggers TranscribePdf
2. **transcribe-proposal** - TranscribePdf → ProposalPdfTranscribed → triggers FillMarkdownTemplate
3. **fill-template** - FillMarkdownTemplate → ProposalMarkdownTemplateFilled → updates ProposalMarkdown query
4. **trigger-evaluation** - TriggerEvaluation → MetricEvaluationStarted → triggers EvaluateMetric
5. **evaluate-metric** - EvaluateMetric → ProposalMetricEvaluated → updates EvaluatedProposal query
6. **generate-recommendation** - GenerateRecommendation → ProposalRecommendationGenerated → updates EvaluatedProposal query

### Extracted Entities:

1. **ProposalEntity** (Proposal swimlane)
   - Events: ProposalPdfUploaded, ProposalPdfTranscribed, ProposalMarkdownTemplateFilled, ProposalRecommendationGenerated

2. **ProposalMetricEvaluationEntity** (Proposal Metric Evaluation swimlane)
   - Events: MetricEvaluationStarted, ProposalMetricEvaluated

## NEOHASKELL TYPE MAPPINGS

| Event Model Type | NeoHaskell Type |
|------------------|-----------------|
| UUID | `Uuid` |
| Text | `Text` |
| Int | `Int` |
| DateTime | `Int64` (epoch) or custom DateTime |
| ListOf X | `Array X` |
| FileRef | `FileRef` (from Service.FileUpload.Core) |
| PdfFile | `FileRef` |
| MarkdownText | `Text` |
| MetricType | Custom sum type |
| MetricScore | Custom record type |

## IMPLEMENTATION ORDER

When implementing slices, follow left-to-right order (temporal order):

1. Start with the leftmost slice (first user action)
2. Implement its command, event, entity update
3. Implement any integrations it triggers
4. Move to the next slice that depends on previous events
5. Implement queries when their source events are ready

This ensures each slice can be tested independently.

## VERIFICATION CHECKLIST

After parsing a diagram, verify:

- [ ] All blue boxes have corresponding Command files
- [ ] All orange boxes are in entity Event sum types
- [ ] All green boxes have corresponding Query files
- [ ] All arrows between contexts have Integration handlers
- [ ] Each slice has at least one Hurl test
- [ ] Entity relationships match swimlane boundaries
