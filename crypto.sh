#!/bin/bash

WORKDIR="tmp"
symm_key_path="$WORKDIR/symm_key"

# Function for showing the user how the script is meant to be used
show_help() {
cat << EOF
Usage:
${0##*/} -e [public_key_1] [public_key_2] [public_key_3] [private_key] [plaintext_file] [encrypted_file]
                -=-  OR  -=-
${0##*/} -d [private_key] [public_key] [encrypted_file] [decrypted_file]


This program uses a crypto that allows a user to send data that can be decrypted by three different recipients
while also providing confidentiality, integrity and authenticity.

     -e          Encrypts data using this crypto
     -d          Decrypts data using this crypto
     -h          display this help and exit

EOF
}

# Function for printing how to use the script before exiting
error_quit() {
echo "Error: $1"
echo "Run with -h flag for help on how to use the script"
exit 1
}

# Function for removing temporary folder and exiting
exit_clean() {
  rm -r "$WORKDIR"
  exit 1
}

# We use mode to differentiate between the encrypt and decrypt mode of use
mode=0

# We parse the arguments here to decrypt and encrypt in the right cases
while getopts "deh" opt; do
  case $opt in
  e)
    mode=1
    ;;
  d)
    mode=2
    ;;
  h)
    show_help
    exit 0
    ;;
  '?')
    show_help >&2
    exit 1
    ;;
  esac
done

if [ $mode == 0 ]; then
  error_quit "Mode was not set to encrypt or decrypt"
fi

rm -rf $WORKDIR
mkdir -p $WORKDIR

if [ $mode == 1 ]; then # This is for encrypting
  if [ $# != 7 ]; then
    error_quit "Error: Invalid number of arguments"
  fi

  ## Arguments
  # $2 -> public key 1
  # $3 -> public key 2
  # $4 -> public key 3
  # $5 -> private key
  # $6 -> data file
  # $7 -> output (encrypted) file

  echo "Encrypting file $6 to be shared with group"

  # Start by generating a symmetric key that will be used to encrypt the data
  openssl rand 256 > $symm_key_path

  # Use all the public keys to encrypt the symmetric key. A valid recipient should be able to decrypt one of the key files
  openssl rsautl -encrypt -inkey "$2" -pubin -in $symm_key_path -out $WORKDIR/key1.penc
  openssl rsautl -encrypt -inkey "$3" -pubin -in $symm_key_path -out $WORKDIR/key2.penc
  openssl rsautl -encrypt -inkey "$4" -pubin -in $symm_key_path -out $WORKDIR/key3.penc

  # Create a signed digest of the data file signed with the private key to ensure integrity and provide authenticity
  openssl dgst -sha512 -sign "$5" -out $WORKDIR/digest.sha512 "$6"

  if [ $? -ne 0 ]; then
    echo "Unable to generate integrity check for file $5"
    exit_clean
  fi

  # Actually encrypt the data file using the symmetric key
  openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -in "$6" -out $WORKDIR/data.enc -pass file:$symm_key_path

  if [ $? -ne 0 ]; then
    echo "Unable to encrypt file with generated key"
    exit_clean
  fi

  # Make sure we delete the symm key so that it needs to be decrypted by the receivers
  rm $symm_key_path

  # Create the output file
  tar czf "$7" $WORKDIR > /dev/null 2>&1

  if [ $? -ne 0 ]; then
    echo "Unable to compress to build cipherfile"
    exit_clean
  fi

  # The work is done
  echo "Successfully encrypted data, output file: $7"
fi

if [ $mode == 2 ]; then # This is for decryption
  if [ $# != 5 ]; then
      error_quit "Error: Invalid number of arguments"
  fi

  ## Arguments
  # $2 -> private key (own)
  # $3 -> public key (sender's)
  # $4 -> encrypted file
  # $5 -> output (decrypted) file

  echo "Decrypting file $4"

  # Extract ciphertext to tmp folder
  tar -xzvf "$4" > /dev/null 2>&1

  if [ $? -ne 0 ]; then
    echo "Unable to decompress $4, file is corrupted."
    exit_clean
  fi

  COULD_DECRYPT=1

  # Try to decrypt one of the key files using the receiver's private key
  for i in {1..3}
    do
      openssl rsautl -decrypt -inkey "$2" -in "$WORKDIR/key$i.penc" -out $symm_key_path > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        COULD_DECRYPT=0
        break
      fi
    done
  
  # If we are successful then the $symm_key_path file exists and is not empty (-s), exit if fail
  if [ $COULD_DECRYPT -ne 0 ]; then
    echo "You do not have the ability to decrypt the file"
    exit_clean
  fi

  # We can now decrypt the data itself with the symmetric key we retrieved
  openssl enc -d -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -in $WORKDIR/data.enc -out $WORKDIR/decrypted \
    -pass file:$symm_key_path > /dev/null 2>&1

  if [ ! -f $WORKDIR/decrypted ]; then
    echo "Unable to decrypt the file with the symmetric key. The cipher file is probably corrupted."
    exit_clean
  fi

  # Lastly we check the integrity of the data file with the sender's pub key as well to confirm authenticity
  openssl dgst -sha512 -verify "$3" -signature $WORKDIR/digest.sha512 $WORKDIR/decrypted > /dev/null 2>&1
  FILE_INTEGRITY=$?

  if [ $FILE_INTEGRITY -eq 0 ]; then
    echo "Successfully decrypted, verified integrity and authenticity of file"
  else
    echo "File was decrypted but could not be verified as authentic. Aborting."
    exit_clean
  fi

  # Move the decrypted file to the desired location. Work is done
  mv $WORKDIR/decrypted "$5"
fi

# Cleanup after us in the regular flow
rm -rf $WORKDIR
exit 0

