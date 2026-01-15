# frozen_string_literal: true

RSpec.describe NETSNMP::Encryption::AES256 do
  let(:priv_key) { "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f".b }
  let(:engine_boots) { 1 }
  let(:engine_time) { 100 }
  let(:plaintext) { "\x30\x0e\x04\x00\x04\x00\xa0\x08\x02\x01\x01\x02\x01\x00\x30\x00".b }

  subject { described_class.new(priv_key) }

  describe "#encrypt and #decrypt" do
    it "round-trips encryption and decryption" do
      encrypted_data, salt = subject.encrypt(plaintext.dup, engine_boots: engine_boots, engine_time: engine_time)

      decrypted_data = subject.decrypt(encrypted_data, salt: salt, engine_boots: engine_boots, engine_time: engine_time)

      expect(decrypted_data).to eq(plaintext)
    end

    it "produces different ciphertext than AES128 with same inputs" do
      aes128_key = priv_key[0, 16]
      aes128 = NETSNMP::Encryption::AES.new(aes128_key)

      # Use fresh instances to ensure same local counter
      aes256 = described_class.new(priv_key, local: 42)
      aes128_instance = NETSNMP::Encryption::AES.new(aes128_key, local: 42)

      encrypted_256, salt_256 = aes256.encrypt(plaintext.dup, engine_boots: engine_boots, engine_time: engine_time)
      encrypted_128, salt_128 = aes128_instance.encrypt(plaintext.dup, engine_boots: engine_boots, engine_time: engine_time)

      # Same salt (since same local counter), but different ciphertext
      expect(salt_256).to eq(salt_128)
      expect(encrypted_256).not_to eq(encrypted_128)
    end
  end

  describe "#decrypt" do
    it "raises error for empty salt" do
      encrypted_data, _salt = subject.encrypt(plaintext.dup, engine_boots: engine_boots, engine_time: engine_time)

      expect {
        subject.decrypt(encrypted_data, salt: "", engine_boots: engine_boots, engine_time: engine_time)
      }.to raise_error(NETSNMP::Error, "invalid priv salt received")
    end

    it "raises error for invalid salt length" do
      encrypted_data, _salt = subject.encrypt(plaintext.dup, engine_boots: engine_boots, engine_time: engine_time)

      expect {
        subject.decrypt(encrypted_data, salt: "\x00\x01\x02", engine_boots: engine_boots, engine_time: engine_time)
      }.to raise_error(NETSNMP::Error, "invalid priv salt received")
    end
  end

  describe "key size" do
    it "uses 32 bytes of the priv_key" do
      # Verify that the key is extracted correctly
      expect(subject.send(:aes_key).length).to eq(32)
      expect(subject.send(:aes_key)).to eq(priv_key[0, 32])
    end
  end
end
