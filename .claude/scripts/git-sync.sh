#!/bin/sh
# İki kişi aynı repoda çalışıyor: oturum başında çek, her tur sonunda gönder.
# Kullanım: git-sync.sh pull | push
cd "$(git rev-parse --show-toplevel)" || exit 0

case "$1" in
pull)
  git fetch -q origin || { echo "git-sync: fetch başarısız (internet?), pull atlandı."; exit 0; }
  if [ -z "$(git log HEAD..@{u} --oneline 2>/dev/null)" ]; then exit 0; fi
  if git pull -q --rebase --autostash; then
    echo "git-sync: arkadaşının yeni commit'leri çekildi:"
    git log --oneline ORIG_HEAD..HEAD 2>/dev/null | head -10
  else
    echo "git-sync: pull --rebase çakıştı. Önce çakışmayı çöz (git status), sonra işe başla."
  fi
  ;;
push)
  # Stop hook tekrar tetiklendiyse bir daha engelleme, sonsuz döngü olmasın.
  input=$(cat)
  if [ -z "$(git log @{u}..HEAD --oneline 2>/dev/null)" ]; then exit 0; fi
  git push -q 2>/dev/null && exit 0
  git pull -q --rebase --autostash 2>/dev/null && git push -q 2>/dev/null && exit 0
  case "$input" in *'"stop_hook_active":true'*) exit 0 ;; esac
  echo "git-sync: push başarısız. Rebase çakışması olabilir; git status'a bak, çöz ve push'la." >&2
  exit 2
  ;;
esac
