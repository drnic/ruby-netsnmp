# Pull Request: Add GETBULK support for SNMPv2c and v3

**Target Repository:** `swisscom/ruby-netsnmp`
**Source Branch:** `drnic:claude/plan-getbulk-support-UUOlQ`
**Target Branch:** `swisscom:master`

---

## Summary

Implements SNMP GETBULK operation for efficient bulk retrieval of multiple values in a single request. This addresses the TODO item mentioned in the README about missing GETBULK support.

GETBULK is a SNMPv2c/v3-only operation that efficiently retrieves multiple variable bindings in a single request, making it much more efficient than repeatedly calling GETNEXT, especially for walking large tables.

## Changes

### Core Implementation

- **PDU Type Support** (`lib/netsnmp/pdu.rb:51`)
  - Enabled GETBULK PDU type (type 5) for encoding/decoding

- **Client Method** (`lib/netsnmp/client.rb:118-127`)
  - Implemented `Client#get_bulk` method with parameters:
    - `*oid_opts`: OIDs to query
    - `non_repeaters: 0`: Number of scalar OIDs at the start
    - `max_repetitions: 10`: Maximum iterations for remaining OIDs
  - Added version validation to raise error for SNMPv1 (GETBULK is v2c/v3 only)

- **Session Enhancement** (`lib/netsnmp/session.rb:11`)
  - Added `attr_reader :version` to enable version checks

- **Type Signatures**
  - Updated `sig/pdu.rbs:2` to include `:getbulk` type
  - Added `get_bulk` method signature in `sig/client.rbs:14-15`

### Test Coverage

- **Unit Tests** (`spec/pdu_spec.rb:38-91`)
  - GETBULK PDU encoding with type 5
  - DER format encoding/decoding
  - Preservation of `non_repeaters` and `max_repetitions` parameters

- **Integration Tests** (`spec/support/request_examples.rb:57-84`)
  - Multiple varbinds retrieval
  - `max_repetitions` parameter handling
  - `non_repeaters` parameter handling
  - Shared examples now include GETBULK tests for v2c and v3

- **Error Handling** (`spec/client_spec.rb:42-46`)
  - SNMPv1 version validation error test

## Usage Example

```ruby
# Initialize client with SNMPv2c or v3
client = NETSNMP::Client.new(host: "localhost", version: "2c", community: "public")

# Basic GETBULK request
results = client.get_bulk(oid: "1.3.6.1.2.1.1", max_repetitions: 10)
# Returns: [["1.3.6.1.2.1.1.1.0", "value1"], ["1.3.6.1.2.1.1.2.0", "value2"], ...]

# With non_repeaters for mixed scalar and table OIDs
results = client.get_bulk(
  { oid: "1.3.6.1.2.1.1.1.0" },  # Scalar OID (non-repeating)
  { oid: "1.3.6.1.2.1.2.2.1" },  # Table OID (repeating)
  non_repeaters: 1,
  max_repetitions: 5
)

# With block for access to raw PDU
client.get_bulk(oid: "1.3.6.1.2.1.1", max_repetitions: 10) do |response_pdu|
  puts "Request ID: #{response_pdu.request_id}"
end
```

## Implementation Notes

As per RFC 1905, GETBULK reuses PDU fields:
- `error_status` field → `non_repeaters` parameter
- `error_index` field → `max_repetitions` parameter

This is standard SNMP protocol behavior and correctly implemented using `instance_variable_set` to set these internal fields.

## Testing

### Running Tests

The tests require the SNMP simulator to be running. There are several ways to run the tests:

#### Option 1: Using Docker (Recommended)

```bash
# For Ruby 3.3
docker-compose -f docker-compose.yml -f docker-compose-ruby-3.3.yml run netsnmp

# For Ruby 3.2
docker-compose -f docker-compose.yml -f docker-compose-ruby-3.2.yml run netsnmp

# For other versions, see available docker-compose-ruby-*.yml files
```

#### Option 2: Manual Setup

If you prefer to run tests without Docker:

1. Install and start the SNMP simulator:
   ```bash
   pip install snmpsim
   # Start simulator (configuration in spec/support/snmpsim/)
   ```

2. Set environment variables:
   ```bash
   export SNMP_HOST=localhost
   export SNMP_PORT=1161
   ```

3. Run the tests:
   ```bash
   bundle install
   bundle exec rspec

   # Or run specific tests:
   bundle exec rspec spec/pdu_spec.rb
   bundle exec rspec spec/client_spec.rb
   ```

### Test Results

All syntax checks pass:
```
lib/netsnmp/client.rb - Syntax OK
lib/netsnmp/pdu.rb - Syntax OK
lib/netsnmp/session.rb - Syntax OK
```

The implementation follows existing patterns in the codebase and is ready for integration testing against the SNMP simulator.

## Checklist

- [x] Implementation follows existing code patterns
- [x] Unit tests added for PDU encoding/decoding
- [x] Integration tests added using shared examples
- [x] Error handling tests for version validation
- [x] Type signatures updated (RBS)
- [x] Documentation added (inline comments)
- [x] All Ruby syntax checks pass
- [ ] Tests run against SNMP simulator (requires Docker environment)

## Related Issues

Addresses the TODO item in README.md line 318:
> * No getbulk support.

## Files Changed

```
lib/netsnmp/client.rb            | 34 +++++++++++++------------
lib/netsnmp/pdu.rb               |  2 +-
lib/netsnmp/session.rb           |  2 ++
sig/client.rbs                   |  3 +++
sig/pdu.rbs                      |  2 +-
spec/client_spec.rb              |  6 +++++
spec/pdu_spec.rb                 | 55 ++++++++++++++++++++++++++++++++++++++++
spec/support/request_examples.rb | 29 +++++++++++++++++++++
8 files changed, 115 insertions(+), 18 deletions(-)
```
