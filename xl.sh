#!/bin/bash

BASE_URL="https://my.xl.co.id"
FC_CODE="3c71892a-852c-4a0f-8cb5-9cf731e26508"
OAID="test-device-id"

TOKEN_FILE="xl_token.txt"

# Fungsi kirim OTP dengan header mirip aplikasi XL
function request_otp() {
  local msisdn="$1"
  RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/preauth/otp/request" \
    -H "User-Agent: okhttp/3.14.7" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Origin: https://my.xl.co.id" \
    -H "Referer: https://my.xl.co.id/" \
    -d "{\"msisdn\":\"$msisdn\"}")
  HTTP=$(echo "$RESP" | tail -n1)
  BODY=$(echo "$RESP" | sed '$d')
  echo "$HTTP|$BODY"
}

# Login setelah OTP benar
function do_login() {
  local msisdn="$1"
  local otp="$2"
  RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/login/otp" \
    -H "User-Agent: okhttp/3.14.7" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Origin: https://my.xl.co.id" \
    -H "Referer: https://my.xl.co.id/" \
    -d "{\"msisdn\":\"$msisdn\", \"otp\":\"$otp\"}")
  HTTP=$(echo "$RESP" | tail -n1)
  BODY=$(echo "$RESP" | sed '$d')
  echo "$HTTP|$BODY"
}

# Simpan token login
function save_token() {
  echo "$1" > "$TOKEN_FILE"
}

function load_token() {
  if [ -f "$TOKEN_FILE" ]; then
    cat "$TOKEN_FILE"
  else
    echo ""
  fi
}

# Cek kuota
function check_quota() {
  local token="$1"
  CURL_RESP=$(curl -s -X GET "$BASE_URL/api/v1.0/account/balance-quota" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/json")

  echo "Paket & Kuota saat ini:"
  echo "$CURL_RESP" | jq '.balanceQuota[] | {name, quota, unit}'
}

# Beli paket via FC Code
function purchase_package() {
  local token="$1"
  RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/api/v1.0/package/prices" \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{\"productCode\": \"$FC_CODE\", \"paymentMethod\": \"pulsa\"}")
  HTTP=$(echo "$RESP" | tail -n1)
  BODY=$(echo "$RESP" | sed '$d')

  if [ "$HTTP" -eq 200 ]; then
    echo "Pembelian berhasil!"
    echo "$BODY" | jq
  else
    echo "Gagal membeli paket."
    echo "$HTTP: $BODY"
  fi
}

# Menu utama
function main_menu() {
  echo "=============================="
  echo " XL CLI - Menu Utama"
  echo "=============================="
  echo "1. Beli Paket Pros Champion (FC: $FC_CODE)"
  echo "2. Cek Kuota"
  echo "3. Keluar"
  echo -n "Pilih opsi: "
  read opsi

  case $opsi in
    1)
      beli_paket
      ;;
    2)
      cek_kuota
      ;;
    3)
      exit 0
      ;;
    *)
      echo "Pilihan tidak valid!"
      ;;
  esac

  echo ""
  main_menu
}

# Proses login dan pembelian
function beli_paket() {
  local token=$(load_token)

  if [ -z "$token" ]; then
    echo "Anda belum login, login terlebih dahulu."
    echo -n "Masukkan nomor XL (contoh: 0812xxxxxxx): "
    read msisdn

    echo "Mengirim OTP ke $msisdn..."
    RESP=$(request_otp "$msisdn")

    CODE=$(echo "$RESP" | cut -d"|" -f1)
    BODY=$(echo "$RESP" | cut -d"|" -f2)

    if [ "$CODE" -ne 200 ]; then
      echo "Gagal mengirim OTP. Status: $CODE"
      echo "$BODY"
      return
    fi

    echo -n "Masukkan OTP yang diterima: "
    read otp

    LOGIN_RESP=$(do_login "$msisdn" "$otp")
    LOGIN_CODE=$(echo "$LOGIN_RESP" | cut -d"|" -f1)
    LOGIN_BODY=$(echo "$LOGIN_RESP" | cut -d"|" -f2)

    if [ "$LOGIN_CODE" -ne 200 ]; then
      echo "Login gagal. Status: $LOGIN_CODE"
      echo "$LOGIN_BODY"
      return
    fi

    token=$(echo "$LOGIN_BODY" | jq -r '.access_token')
    save_token "$token"
  fi

  purchase_package "$token"
}

# Cek kuota
function cek_kuota() {
  local token=$(load_token)

  if [ -z "$token" ]; then
    echo "Anda belum login, login terlebih dahulu."
    return
  fi

  check_quota "$token"
}

# Start aplikasi
main_menu
