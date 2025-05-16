#!/bin/bash

# Alias setup

DATE=$(date +%Y-%m-%d)

function add_savings() {
    read -p "Description: " description
    read -p "Amount (₱): " amount 
    echo "$DATE * $description
    assets:bank:savings  ₱$amount
    expenses:unspecified" >> ~/.config/unknown/savings/savings.journal
    show_total
}

function deduct_savings() {
    read -p "Description: " description
    read -p "Amount (₱): " amount 
    echo "$DATE * $description
    assets:bank:savings  -₱$amount
    expenses:unspecified" >> ~/.config/unknown/savings/savings.journal
    show_total
}

function show_total() {
    hledger -f ~/.config/unknown/savings/savings.journal bal assets:bank:savings
}

# Prompt
echo "[1] Deposit"
echo "[2] Withdraw"
read -p "Enter Number: " choice

case $choice in
    1)
        add_savings
        ;;
    2)
        deduct_savings
        ;;
    *)
        echo "Wrong choice"
        ;;
esac
