# Crypto_scheme

## Example usage

Creating the keys to use
```shell script
# Make the file executable
chmod +x ./gen_keys.sh
./gen_keys.sh
```

Encrypt using the generated keys, using key1 as the sender.
```shell script
chmod +x ./crypto.sh
./crypto.sh -e keys/key2.pub keys/key3.pub keys/key4.pub keys/key1.pem plain.txt cipher
```

Decrypt the file as user 4 for example
```shell script
./crypto.sh -d keys/key4.pem keys/key1.pub cipher decrypted
```