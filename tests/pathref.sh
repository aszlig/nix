source common.sh

clearStore

echo 'testing good...'
nix-build pathref.nix -A good --no-out-link

# these do not work yet:
#echo 'testing bad...'
#nix-build pathref.nix -A bad --no-out-link && fail "should fail"
