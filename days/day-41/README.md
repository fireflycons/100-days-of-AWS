## Task: Securing Data with AWS KMS
The Nautilus DevOps team is focusing on improving their data security by using AWS KMS. Your task is to create a KMS key and manage the encryption and decryption of a pre-existing sensitive file using the KMS key.

**Specific Requirements:**
1. Create a symmetric KMS key named `devops-KMS-Key` to manage encryption and decryption.
2. Encrypt the provided `SensitiveData.txt` file (located in `/root/`), base64 encode the ciphertext, and save the encrypted version as `EncryptedData.bin` in the `/root/` directory.
3. Try to decrypt the same and verify that the decrypted data matches the original file.
Make sure that the KMS key is correctly configured. The validation script will test your configuration by decrypting the `EncryptedData.bin` file using the KMS key you created.

---