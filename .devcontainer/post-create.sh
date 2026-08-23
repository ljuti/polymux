#!/usr/bin/env bash
set -euo pipefail

bundle install

# Export vars from /workspace/.env (if present) in every new shell.
# /etc/profile.d covers login shells, ~/.bashrc covers interactive non-login ones.
cat > /etc/profile.d/polymux-env.sh <<'EOF'
# Load dev secrets from /workspace/.env if present (see .env.example)
if [ -f /workspace/.env ]; then
  set -a
  . /workspace/.env
  set +a
fi
EOF

if ! grep -qs "polymux-env" /root/.bashrc; then
  {
    echo ""
    echo "# Load dev secrets from /workspace/.env if present"
    echo 'if [ -f /workspace/.env ]; then set -a; . /workspace/.env; set +a; fi'
  } >> /root/.bashrc
fi
