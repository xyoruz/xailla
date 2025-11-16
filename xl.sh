#!/bin/bash

BASE_URL="https://my.xl.co.id"
FC_CODE="3c71892a-852c-4a0f-8cb5-9cf731e26508"
TOKEN_FILE="$HOME/.xl_token"

# Fungsi login
function login() {
  echo "Masukkan nomor XL (contoh: 0812xxxxxxx):"
  read MSISDN

  echo "Mengirim OTP ke $MSISDN..."
  curl -s -X POST "$BASE_URL/preauth/otp/request" \
    -H "Content-Type: application/json" \
    -d "{\"msisdn\":\"$MSISDN\"}"

  echo "Masukkan OTP yang diterima:"
  read OTP

  TOKEN=$(curl -s -X POST "$BASE_URL/preauth/login" \
    -H "Content-Type: application/json" \
    -d "{\"msisdn\":\"$MSISDN\",\"otp\":\"$OTP\"}" | jq -r '.token')

  if [ "$TOKEN" != "null" ]; then
    echo "$TOKEN" > "$TOKEN_FILE"
    echo "Login berhasil!"
  else
    echo "Login gagal, coba lagi."
    exit 1
  fi
}

# Fungsi menampilkan informasi produk
function info_produk() {
  if [ ! -f "$TOKEN_FILE" ]; then
    echo "Anda belum login, login terlebih dahulu."
    login
  fi

  TOKEN=$(cat "$TOKEN_FILE")
  echo "Mengambil informasi produk FC..."

  RESP=$(curl -s -X GET "$BASE_URL/purchase/detail/$FC_CODE" \
    -H "Authorization: Bearer $TOKEN")

  PRODUCT=$(echo "$RESP" | jq -r '.productName')
  PRICE=$(echo "$RESP" | jq -r '.price')
  VALID=$(echo "$RESP" | jq -r '.validity')

  if [ "$PRODUCT" != "null" ]; then
    echo "=== Detail Produk ==="
    echo "Nama   : $PRODUCT"
    echo "Harga  : Rp $PRICE"
    echo "Masa Aktif : $VALID"
  else
    echo "Gagal mengambil info produk."
  fi
}

# Fungsi pembelian
function beli_paket() {
  if [ ! -f "$TOKEN_FILE" ]; then
    echo "Anda belum login, login terlebih dahulu."
    login
  fi

  TOKEN=$(cat "$TOKEN_FILE")
  echo "Pilih metode pembayaran:"
  echo "1. DANA"
  echo "2. Pulsa"
  read -p "Metode [1/2]: " METHOD

  if [ "$METHOD" == "1" ]; then
    PAYMENT_METHOD="EWALLET_DANA"
  elif [ "$METHOD" == "2" ]; then
    PAYMENT_METHOD="BALANCE"
  else
    echo "Metode pembayaran tidak valid."
    exit 1
  fi

  echo "Memproses pembelian..."

  RESP=$(curl -s -X POST "$BASE_URL/purchase/with-fc" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"fc\":\"$FC_CODE\",\"paymentMethod\":\"$PAYMENT_METHOD\"}")

  echo "Respons server:"
  echo "$RESP"
}

# Fungsi cek kuota
function cek_kuota() {
  if [ ! -f "$TOKEN_FILE" ]; then
    echo "Anda belum login, login terlebih dahulu."
    login
  fi

  TOKEN=$(cat "$TOKEN_FILE")
  echo "Mengambil informasi kuota..."

  RESP=$(curl -s -X GET "$BASE_URL/dashboard" \
    -H "Authorization: Bearer $TOKEN")

  echo "Informasi paket/kuota:"
  echo "$RESP" | jq
}

# Menu
echo "=== Menu Pembelian Paket XL ==="
echo "1. Lihat Info & Harga Paket Pro Champion"
echo "2. Beli Paket (Pilih metode pembayaran)"
echo "3. Cek Kuota"
echo "4. Keluar"
echo "Pilih opsi [1/2/3/4]:"
read PILIHAN

case $PILIHAN in
  1)
    info_produk
    ;;
  2)
    beli_paket
    ;;
  3)
    cek_kuota
    ;;
  4)
    echo "Keluar..."
    exit
    ;;
  *)
    echo "Pilihan tidak valid"
    ;;
esac