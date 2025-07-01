# Team Create Enhancement Plugin - Product Requirements Document (PRD)

## Overview

**Product Name**: Team Create Enhancer (TCE)

**Purpose**: To solve pain points in Roblox Studio's Team Create feature by providing a plugin with real-time collaboration, permission control, asset coordination, and external integrations, tailored for professional development teams.

**Target Users**: Professional Roblox developers and teams (3+ members), including studios with 12-50+ developers.

**Business Model**: Freemium SaaS with Pro and Enterprise tiers.

---

## Goals

* Improve permission management inside Team Create.
* Add reliable connection monitoring and auto-recovery.
* Introduce asset-level coordination tools.
* Provide seamless Discord integration.
* Offer scalable collaboration tools for large studios.

---

## Feature List

### Tier 1 - Critical Foundation

1. **Role-Based Permission Control**

   * Assign roles (e.g., Script Only, Build Only)
   * Role groups with custom permissions
2. **Connection Monitor + Auto-Recovery**

   * Detect disconnects
   * Save progress snapshots
   * Alert users of unstable sessions
3. **Conflict Resolution (Basic)**

   * Warn when editing same item
   * Temporary lock on in-use items
4. **Discord Webhook Integration**

   * Send alerts on join/leave
   * Status updates (editing, errors)

### Tier 2 - Professional Enhancements

5. **Asset Locking System**

   * Mark assets as "in use"
   * Show editor name and lock status
6. **Progress Tracker**

   * Dashboard with live edits and user presence
7. **Task Assignment**

   * Built-in to-do/task list with ownership and deadlines
8. **Asset Organization Tools**

   * Tagging, search filters, type grouping

### Tier 3 - Enterprise Features

9. **Full Version Control System**

   * Git-style history for all asset types
   * Diff and rollback tools
10. **External Tool Integrations**

    * GitHub, Notion, Trello, Jira
11. **Team Analytics Dashboard**

    * Activity logs, feature usage, session length
12. **Backup & Recovery System**

    * Auto-backup every X minutes
    * Snapshot restoration

---

## Technical Architecture

**Plugin Side (Roblox Studio)**:

* UI built with Studio Widgets and DockWidgetPluginGui
* Plugin: `SetSetting()`/`GetSetting()` for user preferences
* Color-coded cursors and locks for real-time status

**External Service Side**:

* WebSocket server for real-time sync
* Token-based login system
* Secure API endpoints for:

  * Collaboration session creation
  * Role/permission setup
  * Webhook alerts

**Sync Protocol**:

* Operational transformation (OT) for script edits
* Message batching (throttle at 16ms)
* Pub/sub message model for 15+ users
* Heartbeat check every 5s for presence validation

**Security**:

* Token auth via external backend (OAuth optional)
* Rate limiting
* COPPA-safe (age gate required for under-13)

---

## Development Roadmap

### Phase 1 (Months 1-6): MVP

* Role-based permission UI
* WebSocket server for presence
* Basic asset locking + user indicators
* Connection monitor + local snapshots
* Discord webhook integration (simple join/leave)
* Free Tier release

### Phase 2 (Months 6-12): Pro Tier Launch

* Full task manager
* Advanced asset tags and filters
* Presence dashboard
* Git-style version history (scripts only)
* Launch pricing (\$12/user/mo)
* Referral and feedback loops

### Phase 3 (Months 12-24): Enterprise Build-Out

* Full asset version control
* Analytics dashboard
* Notion/GitHub/Trello integrations
* Auto-backup to cloud
* Educational license program
* Enterprise pricing (\$25/user/mo)

---

## Pricing

* **Free Tier**: 3 users max, basic features, community support
* **Professional Tier** (\$12/user/mo): All features, priority support
* **Enterprise Tier** (\$25/user/mo): Custom integrations, analytics, backups

---

## Success Metrics

* 1,000 Free users within 6 months
* 100+ paying teams within 12 months
* 10%+ freemium to paid conversion
* Sub-100ms latency for sync features
* <1% crash/disconnect complaint rate

---

## Risks & Mitigations

| Risk                           | Mitigation                                        |
| ------------------------------ | ------------------------------------------------- |
| Plugin limitations             | Use external services for advanced features       |
| User data leaks                | Keep auth and sensitive ops server-side only      |
| Studio updates breaking plugin | Monitor API changes and patch fast                |
| Low conversion                 | Free tier hooks + strong support to boost upgrade |

---

## Summary

This plugin meets urgent needs of pro Roblox teams: control, stability, coordination, and integration. With phased rollout, smart pricing, and external architecture, it’s built to grow alongside the Roblox developer economy.



🎨 Style Guide for Plugin UI
1. Color Palette
Primary background: Very dark gray (#0f111a or similar)

Secondary panels: Slightly lighter gray with low opacity overlays

Accent colors: Neon blues, purples, magentas, and teals for highlights and charts

Text: White for main content, light gray for labels, with subtle glowing colors for tags/status

Callouts: Use bright green/red for success/error states (e.g., trading graph colors)

2. Typography
Font: Use a modern sans-serif font (like Inter, Manrope, or Poppins)

Weighting: Medium (500) for labels, Bold (700) for headers

Sizes:

Headers: 18-22px

Subtext: 12-14px

Data/Stats: 16px bold

3. UI Components
Panels / Cards:
Rounded corners (8px)

Shadow with subtle glow

Hover state: slight scale-up with a blue/purple glow border

Buttons:
Flat or gradient backgrounds (blue/purple)

White or neon icon/text

Rounded with tight padding (8px vertical, 16px horizontal)

Tabs / Navigation:
Vertical sidebar with icons

Use a selected tab indicator: vertical colored bar or glow dot

Group icons into sections (collapsed view supported)

Charts:
Highcharts or Recharts-style with:

Clean gridlines

Gradient-filled candles/bars

Tooltip on hover

Minimal axis labels

Tables:
Dark rows with slight hover highlight

Bordered cells with neon hover line

Icons for actions (edit, delete) using outlined white or color-accented SVGs

⚙️ UX Patterns
Focus on data clarity: No unnecessary decoration

Quick scan UX: Use color tags, badges, and icons for rapid recognition

Responsive layout: Cards reflow into columns on smaller views

Live data feel: Use blinking or pulsing status dots for activity indication

✨ Micro-interactions
Framer Motion for animation: sliding in panels, fade-in graphs

Animated counters for values

Subtle background blur on modals/popups

🔌 Plugin Usage in Roblox Studio
To align with this style inside Studio:

Use DockWidgetPluginGui with custom frames

Add custom dark-mode widgets with rounded corners and outlined icons

For charts, use web-based panels (HTML viewport or external window) where needed, or represent graphs using color-coded frames for simpler builds