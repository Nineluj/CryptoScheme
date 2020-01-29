DIR="keys"
mkdir -p $DIR

for i in {1..4}
do
  openssl genrsa -out $DIR/key$i.pem 3072
  openssl rsa -in $DIR/key$i.pem -pubout > $DIR/key$i.pub
done