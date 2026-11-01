#!/data/data/com.termux/files/usr/bin/bash
# يشغّل سيرفر بتّه على الجوال (Termux) ويعطيك رابط عام من Cloudflare تلعبون فيه من أي مكان.
# التشغيل: ~/batta/batta.sh      (للإيقاف: Ctrl+C)
cd "$(dirname "$0")"
PORT=8080

termux-wake-lock 2>/dev/null # الجوال ما يوقف Termux وهو مطفي الشاشة

STATIC_DIR=public PORT=$PORT node src/server.js > server.log 2>&1 &
SERVER=$!
trap 'kill $SERVER $TUNNEL 2>/dev/null; termux-wake-unlock 2>/dev/null; echo; echo "وقف السيرفر."' EXIT
sleep 1
if ! kill -0 $SERVER 2>/dev/null; then echo "السيرفر ما اشتغل:"; cat server.log; exit 1; fi
echo "السيرفر شغّال على الجوال (منفذ $PORT). جاري فتح الرابط العام..."

cloudflared tunnel --no-autoupdate --url http://localhost:$PORT > tunnel.log 2>&1 &
TUNNEL=$!
for i in $(seq 1 30); do
  URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' tunnel.log | head -1)
  [ -n "$URL" ] && break
  sleep 1
done
if [ -z "$URL" ]; then echo "ما قدرت أفتح الرابط العام:"; tail -20 tunnel.log; exit 1; fi

echo
echo "=============================================="
echo " رابط اللعب (افتحه بالمتصفح):"
echo "   $URL"
echo
echo " للتطبيق (إعدادات السيرفر):"
echo "   wss://${URL#https://}"
echo "=============================================="
echo " خل Termux مفتوح. الرابط يتغير كل ما تشغّل من جديد."
wait $SERVER
