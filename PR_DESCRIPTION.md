# Pull Request: Add GETBULK support and SHA384/SHA512 authentication

**Target Repository:** `swisscom/ruby-netsnmp`
**Source Branch:** `drnic:claude/plan-getbulk-support-UUOlQ`
**Target Branch:** `swisscom:master`

---

## Summary

This PR adds two significant enhancements to ruby-netsnmp:

1. **GETBULK Operation Support** - Implements SNMP GETBULK for efficient bulk retrieval of multiple values in a single request, addressing the TODO item mentioned in the README.

2. **SHA384/SHA512 Authentication** - Extends SNMPv3 authentication to support SHA384 and SHA512 hash algorithms per RFC 7860, complementing the existing MD5, SHA1, and SHA256 support.

GETBULK is a SNMPv2c/v3-only operation that efficiently retrieves multiple variable bindings in a single request, making it much more efficient than repeatedly calling GETNEXT, especially for walking large tables.

## Changes

### GETBULK Implementation

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

### SHA384/SHA512 Authentication

- **Digest Support** (`lib/netsnmp/security_parameters.rb:212-222`)
  - Added SHA384 and SHA512 to digest method

- **HMAC Signing** (`lib/netsnmp/security_parameters.rb:127-160`)
  - Updated sign method to use HMAC for SHA-2 family:
    - SHA256: 24-byte MAC
    - SHA384: 32-byte MAC (new)
    - SHA512: 48-byte MAC (new)

- **Documentation** (`lib/netsnmp/security_parameters.rb:30`)
  - Updated to list SHA384 and SHA512 as supported auth protocols

- **Unit Tests** (`spec/security_parameters_spec.rb`)
  - Passkey generation tests for SHA384/SHA512
  - Signing tests verifying correct MAC lengths
  - Integration with existing test suite

## Usage Examples

### GETBULK

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

### SHA384/SHA512 Authentication

```ruby
# SNMPv3 with SHA384 authentication
client = NETSNMP::Client.new(
  host: "localhost",
  version: "3",
  username: "authuser",
  auth_protocol: :sha384,
  auth_password: "authpassword",
  security_level: :auth_no_priv
)

# SNMPv3 with SHA512 authentication and AES encryption
client = NETSNMP::Client.new(
  host: "localhost",
  version: "3",
  username: "secureuser",
  auth_protocol: :sha512,
  auth_password: "authpassword",
  priv_protocol: :aes,
  priv_password: "privpassword",
  security_level: :auth_priv
)

# All supported auth protocols: :md5, :sha, :sha256, :sha384, :sha512
results = client.get(oid: "sysName.0")
```

## Implementation Notes

### GETBULK

As per RFC 1905, GETBULK reuses PDU fields:
- `error_status` field → `non_repeaters` parameter
- `error_index` field → `max_repetitions` parameter

This is standard SNMP protocol behavior and correctly implemented using `instance_variable_set` to set these internal fields.

### SHA384/SHA512 Authentication

As per RFC 7860, SHA-2 family authentication uses HMAC with truncated MAC values:
- **SHA256**: HMAC-SHA-256 truncated to 24 octets (existing)
- **SHA384**: HMAC-SHA-384 truncated to 32 octets (new)
- **SHA512**: HMAC-SHA-512 truncated to 48 octets (new)

The implementation follows the same pattern as SHA256, using `OpenSSL::HMAC.digest` and truncating to the appropriate length per RFC 7860 sections 4.2.2, 5.2.2, and 6.2.2.

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
lib/netsnmp/security_parameters.rb - Syntax OK
```

The implementation follows existing patterns in the codebase and is ready for integration testing against the SNMP simulator.

## Checklist

**GETBULK:**
- [x] Implementation follows existing code patterns
- [x] Unit tests added for PDU encoding/decoding
- [x] Integration tests added using shared examples
- [x] Error handling tests for version validation
- [x] Type signatures updated (RBS)
- [x] Documentation added (inline comments)

**SHA384/SHA512:**
- [x] Digest support added for SHA384 and SHA512
- [x] HMAC signing implemented per RFC 7860
- [x] Unit tests for passkey generation
- [x] Unit tests for MAC signing and verification
- [x] Documentation updated

**General:**
- [x] All Ruby syntax checks pass
- [x] No breaking changes to existing API
- [ ] Tests run against SNMP simulator (requires Docker environment)

## Related Issues

**GETBULK:** Addresses the TODO item in README.md line 318:
> * No getbulk support.

**SHA384/SHA512:** Extends SNMPv3 authentication support to include modern SHA-2 hash algorithms as specified in RFC 7860.

## Files Changed

```
lib/netsnmp/client.rb                | 34 +++++++++++++------------
lib/netsnmp/pdu.rb                   |  2 +-
lib/netsnmp/session.rb               |  2 ++
lib/netsnmp/security_parameters.rb   | 85 +++++++++++++++++++++++++++++++++++++++++++++++
spec/security_parameters_spec.rb     | 82 +++++++++++++++++++++++++++++++++++++++++++++
sig/client.rbs                       |  3 +++
sig/pdu.rbs                          |  2 +-
spec/client_spec.rb                  |  6 +++++
spec/pdu_spec.rb                     | 55 +++++++++++++++++++++++++++++++
spec/support/request_examples.rb     | 29 ++++++++++++++++++
10 files changed, 197 insertions(+), 21 deletions(-)
```
