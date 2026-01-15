# frozen_string_literal: true

RSpec.describe NETSNMP::Encryption::AES256 do
  let(:priv_key) { "\x00" * 32 }
  let(:engine_boots) { 1 }
  let(:engine_time) { 1000 }

  subject { described_class.new(priv_key) }

  describe "#encrypt and #decrypt" do
    let(:plaintext) { "\x30\x0e\x04\x06public\x04\x04test".b }

    it "round-trips data correctly" do
      encrypted_data, salt = subject.encrypt(plaintext.dup,
                                             engine_boots: engine_boots,
                                             engine_time: engine_time)

      decryptor = described_class.new(priv_key)
      decrypted = decryptor.decrypt(encrypted_data,
                                    salt: salt,
                                    engine_boots: engine_boots,
                                    engine_time: engine_time)

      expect(decrypted).to eq(plaintext)
    end

    it "produces different ciphertext than AES-128 for same input" do
      aes128 = NETSNMP::Encryption::AES.new(priv_key)
      aes256 = described_class.new(priv_key)

      encrypted_128, _ = aes128.encrypt(plaintext.dup,
                                        engine_boots: engine_boots,
                                        engine_time: engine_time)
      encrypted_256, _ = aes256.encrypt(plaintext.dup,
                                        engine_boots: engine_boots,
                                        engine_time: engine_time)

      expect(encrypted_128).not_to eq(encrypted_256)
    end
  end

  describe "#decrypt" do
    it "raises error for empty salt" do
      expect {
        subject.decrypt("data", salt: "", engine_boots: 1, engine_time: 1)
      }.to raise_error(NETSNMP::Error, "invalid priv salt received")
    end

    it "raises error for invalid salt length" do
      expect {
        subject.decrypt("data", salt: "123", engine_boots: 1, engine_time: 1)
      }.to raise_error(NETSNMP::Error, "invalid priv salt received")
    end
  end
end
