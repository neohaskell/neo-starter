# Full counter lifecycle: create → increment → increment → decrement → query.
# Final expected value: 1 (0 + 1 + 1 - 1).

# --- 1. Create ---------------------------------------------------------------
POST http://localhost:8080/commands/create-counter
Content-Type: application/json
{
  "label": "downloads"
}

HTTP 200
[Captures]
counter_id: jsonpath "$.entityId"
[Asserts]
jsonpath "$.entityId" matches /^[0-9a-f-]{36}$/


# --- 2. First increment ------------------------------------------------------
POST http://localhost:8080/commands/increment-counter
Content-Type: application/json
{
  "entityId": "{{counter_id}}",
  "amount": 1
}

HTTP 200


# --- 3. Second increment -----------------------------------------------------
POST http://localhost:8080/commands/increment-counter
Content-Type: application/json
{
  "entityId": "{{counter_id}}",
  "amount": 1
}

HTTP 200


# --- 4. Decrement ------------------------------------------------------------
POST http://localhost:8080/commands/decrement-counter
Content-Type: application/json
{
  "entityId": "{{counter_id}}",
  "amount": 1
}

HTTP 200


# --- 5. Query — projection is eventually consistent, so we retry ------------
GET http://localhost:8080/queries/counter-view
[Options]
retry: 10
retry-interval: 200

HTTP 200
[Asserts]
jsonpath "$[?(@.counterId == '{{counter_id}}')].value" nth 0 == 1
jsonpath "$[?(@.counterId == '{{counter_id}}')].label" nth 0 == "downloads"


# --- 6. Validation: empty label is rejected ---------------------------------
POST http://localhost:8080/commands/create-counter
Content-Type: application/json
{
  "label": ""
}

HTTP 400
