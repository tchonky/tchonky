<h1 align="center">Daniel Polistchuck</h1>

<p align="center">
  <b>Architect · AI-native software builder · BIM</b><br>
  Nine years modeling buildings in Revit. Now I build the tools I always wished it had,<br>
  with AI agents as my engineering team.
</p>

<p align="center">
  <a href="https://www.linkedin.com/in/danielpolis/">LinkedIn</a> ·
  <a href="mailto:danielpolistchuck@gmail.com">Email</a> ·
  Tel Aviv
</p>

---

I studied Computer Engineering at the University of São Paulo for six years, then spent five more years
there earning my degree in Architecture & Urbanism. For the last nine years I've been an architect at **Knafo Klimor Architects**
in Tel Aviv: modeling, building the office's Revit families and standards, and fixing whatever breaks,
in Revit and in the office's IT.

When AI coding agents arrived, the ideas I'd been collecting for years finally started turning into
software. Working with **Claude Code**, I've built three Revit add-ins and a cloud platform for the
office. I own the product, the architecture and the verification; the agents write most of the code.

> **June → November 2026:** 1,265 commits · 1,800+ automated tests · 90+ written specs and plans ·
> Revit 2023–2027 from one codebase · one developer

## 🛠️ What I've built

### 🏗️ [RVTuk](https://github.com/tchonky/RVTuk): the office's Revit toolkit

One ribbon, one installer, eight tools for the firm's daily work:

- **Family Browser**: the firm's family library, searchable, with thumbnails, parameters and how-to
  notes. Load or update a family into the project in one click.
- **Area Calc**: exports the area plans on a sheet as the DXF + data files that Israel's online
  building-permit system (רישוי זמין) reads automatically.
- **Auto Dimensions**: dimensions every wall, door and window crossing a reference line, in linked
  models too, and re-runs when the design changes.
- **DWG Export**, **Topo Tools**, **Floor ⇄ Topo**, **Room Floors** and **Round Positions** for the
  rest of the repetitive work.

One C# codebase builds for five Revit versions (2023–2027) on three .NET runtimes (Framework 4.8,
.NET 8, .NET 10), with strict Core / UI / Revit layers, a self-elevating installer, and tests that run
on every runtime.

### 🗂️ KKarcDB + KK Hub: the office's project register and intranet <sub>(private)</sub>

The firm had no project register, only folders scattered across individual computers. Now it has one
place for 800+ projects going back to 1979, 750+ consultants, project plans and staff hours.

- **Stack:** ASP.NET Core API on Azure, PostgreSQL on Supabase, Microsoft (Entra ID) sign-in, BIM 360 /
  ACC import through Autodesk Platform Services, and a React + TypeScript hub of small apps sharing one
  shell, in Hebrew and English, light or dark, deployed by GitHub Actions.
- **Messy data in, clean data out:** the consultant lists arrived as 158 spreadsheets with 35 different
  header spellings, and project folders had been named by hand for decades. Re-runnable importers turned
  both into one register.
- **Nothing exposed:** a Windows service in each office dials out to the cloud, so office drives and
  the attendance clocks are reachable without opening the office network.
- **Safe by design:** every edit checks that it isn't overwriting someone else's (compare-and-set) and
  is logged. Schema changes are plain-SQL migrations, rehearsed on a restored copy of production first.

### ✅ KKcheck: automated QA for drawings <sub>(private)</sub>

Checks sheets and plans before they're issued: tags, dimensions, section and elevation references, fire
doors, title blocks. The rules are deterministic, with presets and per-project overrides. Results appear
in a Hebrew, right-to-left pane and as numbered markers on the drawing that are never printed or saved.
From first commit to a field-tested MVP in two days.

### ⚖️ KKompare: compare and reconcile Revit view templates <sub>(private)</sub>

Compares view templates, filters, line and fill patterns and phase filters between two models, or
against JSON snapshots kept in Git, and copies what's missing in one undoable step. Built in three days,
with 184 tests.

### 🔬 DowngRev: "Save as Revit 2023" <sub>(research prototype, private)</sub>

Revit can't save a file to an older version, and Autodesk archived the request back in 2017. I took the
`.rfa` format apart to see why: every file carries Revit's full class schema, and between 2023 and 2024
thousands of classes were renumbered and every element ID widened to 64 bits, so patching the binary is
a dead end. DowngRev re-authors the family instead: Revit 2024 exports it to JSON, Revit 2023 rebuilds it
through the API, and geometric fingerprints, taken with every driving parameter flexed, check that the
copy matches the original.

### 🧪 Exploring now

**RevitMCP**: a Model Context Protocol server that lets AI agents like Claude Code read and edit a live
Revit model.

## 🤖 How I build with AI

Over 85% of my 2026 commits are co-authored with Claude Code. The agents write most of the code; I decide
what gets built, how it's designed, and when it's done.

- **Spec first.** Features start as a written design and a step-by-step plan.
- **Context is part of the codebase.** Every repo has a `CLAUDE.md`: the architecture, the threading
  rules, the gotchas that already cost days, and a list of *decisions that must not be quietly reversed*.
- **Verify against reality.** Tests run on every target runtime, migrations are rehearsed on a copy of
  production, and Revit features are checked inside Revit, version by version. The docs say what has
  been verified and what hasn't.
- **Parallel agents, clean merges.** Several sessions work at once in separate git worktrees, under
  rules that keep them from colliding: one app per branch, shared code merged first.

## 🧰 Toolbox

- **AI:** Claude Code, agentic and spec-driven development, MCP
- **AEC / BIM:** Revit API (2023–2027), families and office standards, Autodesk Platform Services
  (BIM 360 / ACC), DWG / DXF
- **Languages:** C#, TypeScript, Python, SQL, PowerShell
- **Back end:** .NET (Framework 4.8 to .NET 10), ASP.NET Core, SignalR, PostgreSQL, SQLite
- **Front end:** React, Vite, WPF / MVVM, bilingual right-to-left interfaces
- **Cloud and ops:** Azure (App Service, Static Web Apps, Entra ID), Supabase, GitHub Actions, Windows
  services and installers, office networks and backups
- **Data:** pandas, scikit-learn, Jupyter

## 🎓 Background

- **Architecture & Urbanism**, University of São Paulo (IAU-USP), Brazil
- **Computer Engineering**, six years at the University of São Paulo before architecture. It's why I've
  always wanted to know how Revit works underneath, not just how to use it.
- **Data Science bootcamp**, Le Wagon, 2022: Python, machine learning, SQL
- **Nine years at Knafo Klimor Architects**, Tel Aviv: modeling, families, the office's BIM standards,
  Revit and IT troubleshooting, and now its in-house software
- **Languages:** Portuguese (native), English, Hebrew

---

💬 Ask me about the Revit API's sharp edges, running AI agents in parallel, or why Revit can't save to
an older version.

⚡ Still curious about how brains work, the human kind and now the artificial kind. (Mantis shrimp still
have 12 kinds of color receptors; we have three.)
