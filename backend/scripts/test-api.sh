#!/usr/bin/env sh
# Тест API Petio (запустите docker-compose up -d перед запуском)
# Использование: ./scripts/test-api.sh   или   sh scripts/test-api.sh

BASE="http://localhost:8080/v1"

echo "=== 1. Device Auth ==="
REG=$(curl -s -X POST "$BASE/auth/device" -H "Content-Type: application/json" -d '{"device_id":"test-script-device"}')
echo "$REG"
TOKEN=$(echo "$REG" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo "Token: ${TOKEN:0:20}..."

echo ""
echo "=== 2. Профиль ==="
curl -s -X GET "$BASE/profile" -H "Authorization: Bearer $TOKEN" | head -c 200
echo ""

echo ""
echo "=== 3. Список питомцев ==="
curl -s -X GET "$BASE/pets" -H "Authorization: Bearer $TOKEN"
echo ""

echo ""
echo "=== 4. Создать питомца ==="
PET=$(curl -s -X POST "$BASE/pets" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"name":"Барсик","species":"cat","breed":"дворовый","age":"2","weight":4.5,"birth_date":"2022-01-15"}')
echo "$PET"
PET_ID=$(echo "$PET" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "Pet ID: $PET_ID"

echo ""
echo "=== 5. Получить питомца ==="
curl -s -X GET "$BASE/pets/$PET_ID" -H "Authorization: Bearer $TOKEN"
echo ""

echo ""
echo "=== 6. Список напоминаний ==="
curl -s -X GET "$BASE/reminders" -H "Authorization: Bearer $TOKEN"
echo ""

echo ""
echo "=== 7. Список статей ==="
curl -s -X GET "$BASE/articles" -H "Authorization: Bearer $TOKEN" | head -c 300
echo "..."

echo ""
echo "=== 8. Список постов ==="
curl -s -X GET "$BASE/posts" -H "Authorization: Bearer $TOKEN"
echo ""

echo ""
echo "=== 9. Создать чат и отправить сообщение ==="
CHAT=$(curl -s -X POST "$BASE/chats" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"title":"Тест"}')
echo "$CHAT"
CHAT_ID=$(echo "$CHAT" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
curl -s -X POST "$BASE/chats/$CHAT_ID/messages" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"content":"Почему кот мурлыкает?"}'
echo ""

echo ""
echo "=== 10. Swagger UI ==="
echo "Откройте в браузере: http://localhost:8080/swagger/index.html"
