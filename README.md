# ALBU BANK — CC:Tweaked 1.16.5

A simple central banking network for Minecraft 1.16.5 with CC:Tweaked.

## Files

- `installer.lua` — interactive installer. Lets you choose which ALBU BANK component to install.
- `bank_computer.lua` — central bank operator computer. It starts `bank_server.lua` and provides the bank menu.
- `bank_server.lua` — central server. Stores accounts, cards, terminals and transaction logs in files.
- `atm.lua` — ATM. Reads an ALBU card from a disk drive and shows card information, balance and transactions.
- `store_terminal.lua` — shop terminal. First launch registers it to the store owner's card. After that it accepts customer payments.
- `lib/bank_client.lua` — shared network/client library.

## Installer

The easiest way to install the system is to put `installer.lua` on a CC:Tweaked computer and run:

```text
installer
```

The installer provides these choices:

```text
1. Central Bank Computer
2. ATM
3. Store Terminal
4. Bank Server only
5. Everything
6. Custom component
7. Exit
```

The installer automatically downloads the selected files from this repository and creates `/lib` when it is needed. The central bank option installs both `bank_computer.lua` and its required `bank_server.lua` and shared library. ATM and Store Terminal automatically receive the shared client library.

The computer must have the CC:Tweaked HTTP API enabled because the installer downloads files over HTTPS from GitHub.

## Network

Every computer needs a modem. All ALBU machines use:

- Network name: `ALBU_BANK`
- Modem port: `4200`

The programs use direct modem messages, so wired or wireless modem networks can be used. The bank server is the source of truth; ATMs and store terminals never edit account files directly.

## Data layout on the bank computer

The first server start creates:

```text
/albu_bank/
  accounts/
    ACC-000001.dat
    ACC-000002.dat
  cards/
    CARD-000001.dat
  terminals/
    TERM-000001.dat
  logs/
    ACC-000001.log
  next_account.txt
  next_card.txt
  next_terminal.txt
```

Each account has its own `.dat` file. Each account also has its own transaction log.

## Card format

An ALBU card is a writable floppy disk. The bank computer writes `/albu_card.dat` to the card. The card contains the card ID and account ID. The PIN is kept only on the bank server's card record, not on the physical card file.

## Manual setup

The programs can also be copied manually:

```text
/bank_computer.lua
/bank_server.lua
/atm.lua
/store_terminal.lua
/lib/bank_client.lua
```

### Central bank

Run:

```text
bank_computer
```

Use `Create new account + card` to create an account. Insert a writable floppy when the program asks for the card. The program displays the generated PIN; give it to the card owner.

### ATM

Run:

```text
atm
```

Insert the ALBU card, enter its PIN, and choose card information, balance or transactions.

### Store terminal

Run:

```text
store_terminal
```

On first launch, insert the shop owner's card, enter the owner's PIN and enter the store name. The terminal receives a permanent `TERM-XXXXXX` identifier and stores it locally.

For a purchase, select `New payment`, insert the customer's card, enter the customer's PIN, enter the amount and optional description. The server transfers the money from the customer account to the terminal owner's account and creates transaction records for both accounts.

## Important

The server must stay online for ATMs and store terminals to work. Keep the central bank computer running.

The current implementation is designed for a trusted Minecraft RP environment. The central server stores PINs in its protected filesystem and validates all card operations server-side, but the modem protocol is not cryptographically encrypted.
