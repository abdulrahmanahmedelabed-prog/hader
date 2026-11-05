# Hader for Oracle APEX — attendance terminals in your database

Fingerprint, face and palm attendance terminals that push over HTTP talk **straight to your Oracle database**
through ORDS — no middleware server, no Windows box, no extra licence for a separate product. Your APEX
application then reads, writes and synchronises them with a handful of region plug-ins.

* **Read** — punches arrive in real time; what a terminal kept while it was off the network is asked for and
  sent again; nothing is taken twice.
* **Write** — employees, card numbers, passwords and privileges go to the terminals of their area; a person
  removed in APEX is removed from them.
* **Synchronise** — fingerprints, faces and palms enrolled on one terminal reach every terminal of its area;
  the terminals' clocks are kept right; commands are queued, retried and logged.
* **Enrol from the page** — start a finger, face or palm enrolment on a chosen terminal from APEX.
* **Attendance** — shifts, timetables, flexible hours, leave, overtime and the day's result per employee,
  calculated in the database (`HADER_V_ATT_REPORT`).

## Live demo

https://oracleapex.com/ords/f?p=209149 — sign in as **DEMO**, password **Visitor123!@#** (it sees everything and
changes nothing). A sample company: 36 employees, 5 terminals, the last weeks' punches; today's punches keep
arriving. The terminals are simulated: there is no real terminal behind the demo.

## The plug-ins

| Plug-in | Type | What it does |
|---|---|---|
| Hader Cards | Region | The rows of **your own SQL query** as cards (title, line, value, details, picture, link, state colour), each part mapped to a column in Page Designer; refreshes itself and on a *Refresh* action. |
| Hader Attendance Board | Region | Today's rate, present / late / absent / on leave, departments, latest punches. Optional *Source* query of yours. |
| Hader Employee Calendar | Region | One employee's month, day by day, with the punches of a day on a click. Optional *Source* query of yours. |
| Hader Terminals | Region | Every terminal: online state, people, templates and punches it holds, server address, clock, restart, read, send, command log; approve new terminals. |
| Hader Employee on the Terminals | Region | One employee's areas, templates and where they stand on each terminal; enrol from the page. |
| Hader Settings | Region | The settings of the terminals, the attendance rules and the edition/activation. *Groups shown* picks what a page shows. |
| Hader Sync | Dynamic action | Read now, recalculate a period, and wait for the answer. |

## Free edition

Everything above works with **up to 2 terminals**. For more, open *Settings → Edition and activation*, send the
**database code** shown there (`DB-XXXX-XXXX-XXXX-XXXX`) to the vendor, and paste the key you receive. The key is
checked inside the database (no call home, nothing sent anywhere) and is bound to that database. Terminals beyond
the limit are refused politely: they keep their punches and send them once a key takes them.

## Requirements

* Oracle Database 11g or later (tested on 11g XE and 23ai Free).
* Oracle APEX 19.2 or later (the plug-ins are exported in the 19.2 format).
* ORDS, reachable by the terminals over HTTP at the root path `/iclock/...` (a second ORDS listener with context
  path `/`, or a web-server rule `/iclock/*` → `/ords/iclock/*`).

## Install

1. In the schema of your APEX application, run **`hader_apex_install.sql`** (SQL*Plus, SQL Developer, or
   *SQL Workshop → SQL Scripts*). It creates the `HDR_*` / `HADER_*` objects and a one-minute scheduler job.
   Run it again to upgrade; `hader_apex_uninstall.sql` removes exactly what it created.
2. Run **`hdr_ords.sql`** in the same schema to publish the terminals' address with ORDS.
3. In your application: *Shared Components → Plug-ins → Import* each `*_plugin_com_hader_*.sql` file you need.
4. On each terminal: *Communication → Cloud server*: your server's address and port, *Domain name* off.
   New terminals wait for approval on the *Hader Terminals* region (or are taken at once if you allow it).

## Independent product

Hader is an independent product. It is not made, endorsed or supported by any maker of attendance terminals, and
no maker's software, SDK, firmware or documentation is included in it: it speaks the terminals' push
protocol over HTTP, as any server they can be pointed at does. Product names you may know your terminals by are
the trademarks of their owners. The organisation that installs it decides what personal and biometric data it
keeps, and is responsible for it under its own law.

## Licence

The plug-ins' JavaScript and CSS are open to read and adapt for your own applications. The database packages are
supplied wrapped. You may use the free edition at no cost in any organisation; activation keys for more terminals
come from the vendor. See `LICENSE.md`.
