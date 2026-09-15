#!/bin/zsh
# Publishes website/dist to getclockin.netlify.app as it is, for page changes
# between app releases. App releases update the site through publish-mac.sh.
# Every file is downloaded again after the deploy and compared with the local copy.
set -euo pipefail
cd "${0:A:h:h}"
[[ -f website/dist/index.html ]] || { print -u2 'website/dist is missing.'; exit 1; }
if [[ "${1:-}" != --yes ]]; then
  read -r "answer?Deploy website/dist to https://getclockin.netlify.app? [y/N] "
  [[ "$answer" == [yY]* ]] || { print 'Cancelled.'; exit 1; }
fi
/usr/bin/python3 scripts/publish-mac-release.py site
