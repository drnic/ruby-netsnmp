# frozen_string_literal: true

RSpec.describe NETSNMP::PDU do
  let(:get_request_oid) { ".1.3.6.1.2.1.1.1.0" }
  let(:encoded_get_pdu) do
    "0'\002\001\000\004\006public\240\032\002\002?*\002\001\000\002\001\0000\0160\f\006\b+\006\001\002\001\001\001\000\005\000"
  end
  let(:encoded_response_pdu) do
    "0+\002\001\000\004\006public\242\036\002\002'\017\002\001\000\002\001\0000\0220\020\006\b+\006\001\002\001\001\001\000\004\004test"
  end

  describe "#to_der" do
    let(:pdu_get) do
      described_class.build(:get, version: 0,
                                  community: "public",
                                  request_id: 16170)
    end

    context "v1" do
      before { pdu_get.add_varbind(oid: get_request_oid) }
      it { expect(pdu_get.to_der).to eq(encoded_get_pdu.b) }
    end
  end

  describe "#decoding pdus" do
    describe "v1" do
      let(:pdu_response) { described_class.decode(encoded_response_pdu) }
      it { expect(pdu_response.version).to be(0) }
      it { expect(pdu_response.community).to eq("public") }
      it { expect(pdu_response.request_id).to be(9999) }

      it { expect(pdu_response.varbinds.length).to be(1) }
      it { expect(pdu_response.varbinds[0].oid).to eq("1.3.6.1.2.1.1.1.0") }
      it { expect(pdu_response.varbinds[0].value).to eq("test") }
    end
  end

  describe "GETBULK PDU" do
    context "v2c" do
      let(:pdu_getbulk) do
        described_class.build(:getbulk, version: 1,
                                        community: "public",
                                        request_id: 12345,
                                        error_status: 0,
                                        error_index: 10)
      end

      before { pdu_getbulk.add_varbind(oid: get_request_oid) }

      it "encodes with type 5" do
        expect(pdu_getbulk.type).to eq(5)
      end

      it "encodes to DER format" do
        encoded = pdu_getbulk.to_der
        expect(encoded).to be_a(String)
        expect(encoded).not_to be_empty
      end

      it "can be decoded" do
        encoded = pdu_getbulk.to_der
        decoded = described_class.decode(encoded)
        expect(decoded.type).to eq(5)
        expect(decoded.version).to eq(1)
        expect(decoded.community).to eq("public")
        expect(decoded.request_id).to eq(12345)
      end

      it "preserves non_repeaters in error_status field" do
        pdu = described_class.build(:getbulk, version: 1,
                                             community: "public",
                                             error_status: 2,
                                             error_index: 10)
        pdu.add_varbind(oid: get_request_oid)
        encoded = pdu.to_der
        decoded = described_class.decode(encoded)
        expect(decoded.instance_variable_get(:@error_status)).to eq(2)
      end

      it "preserves max_repetitions in error_index field" do
        pdu = described_class.build(:getbulk, version: 1,
                                             community: "public",
                                             error_status: 0,
                                             error_index: 15)
        pdu.add_varbind(oid: get_request_oid)
        encoded = pdu.to_der
        decoded = described_class.decode(encoded)
        expect(decoded.instance_variable_get(:@error_index)).to eq(15)
      end
    end
  end
end
