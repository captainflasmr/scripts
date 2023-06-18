#! /bin/bash
# gpg --recv-keys 4F494A942E4616C2
find ~/.gnupg -type f -exec chmod 600 {} \;
find ~/.gnupg -type d -exec chmod 700 {} \;

find ~/.ssh -type d -exec chmod 0700 {} \;
find ~/.ssh -type f -exec chmod 0600 {} \;
