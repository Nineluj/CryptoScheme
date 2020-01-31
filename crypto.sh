#!/bin/bash

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

error_quit() {
echo "Error: $1"
echo "Run with -h flag for help on how to use the script"
exit 1
}

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

WORKDIR="tmp/"

rm -rf $WORKDIR
mkdir -p $WORKDIR

if [ $mode == 1 ]; then
  if [ $# != 7 ]; then
    error_quit "Error: Invalid number of arguments"
  fi

  # Start by generating a symmetric key that will be used to encrypt the data
  symm_key_path="$WORKDIR/symm_key"
  openssl rand 256 > $symm_key_path

  # Use all the public keys to encrypt the symmetric key
  openssl rsautl -encrypt -inkey "$2" -pubin -in $symm_key_path -out $WORKDIR/key1.penc
  openssl rsautl -encrypt -inkey "$3" -pubin -in $symm_key_path -out $WORKDIR/key2.penc
  openssl rsautl -encrypt -inkey "$4" -pubin -in $symm_key_path -out $WORKDIR/key3.penc

  # Create a signed digest of the data file
  openssl rsautl -sha512 -sign "$5" -out $WORKDIR/digest.sha512 "$6"

  # Encrypt the data file using the symmetric key
  openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -in "$6" -out $WORKDIR/data.enc -pass file:$symm_key_path

  # Make sure we delete the symm key so that it needs to be decrypted by the receivers instead
  rm $symm_key_path

  # Create the output file
  tar czf "$7" $WORKDIR
fi

if [ $mode == 2 ]; then
  if [ $# != 5 ]; then
      error_quit "Error: Invalid number of arguments"
    fi
fi

rm -rf $WORKDIR