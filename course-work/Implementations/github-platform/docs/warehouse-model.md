# Data Warehouse Model - GitHub Platform Analytics

The data warehouse implements a **star schema** optimized for OLAP (Online Analytical Processing) queries, enabling business intelligence and analytical reporting on GitHub platform activity.

### Design Principles

- **Star Schema**: Central fact tables surrounded by dimension tables
- **SCD Type 1**: Slowly Changing Dimensions - overwrite historical data (simplest approach)
- **Pre-aggregation**: Generated columns for commonly calculated metrics
- **Time Intelligence**: Separate date and time dimensions for flexible temporal analysis
- **Composite Keys**: Optimized indexing for common query patterns

---

## Dimension Tables (6)

### 1. Dim_Date

**Purpose:** Time dimension with calendar hierarchies  
**Granularity:** Daily  
**Primary Key:** `date_key` (INTEGER, format: YYYYMMDD)

**Attributes:**

- `full_date` (DATE) - Actual date value
- **Hierarchies:**
  - Year → Quarter → Month → Week → Day
  - `year`, `quarter`, `month`, `week`
  - `day_of_year`, `day_of_month`, `day_of_week`
- **Descriptive:**
  - `month_name` (January, February, ...)
  - `day_name` (Monday, Tuesday, ...)
  - `is_weekend` (0/1 flag)

**Records:** 1,461 (2023-2026, 4 years of dates)

---

### 2. Dim_Time

**Purpose:** Time-of-day dimension for intraday analysis  
**Granularity:** 15-minute intervals  
**Primary Key:** `time_key` (INTEGER, format: HHMM)

**Attributes:**

- `hour` (0-23)
- `minute` (0, 15, 30, 45)
- `time_period` (Morning, Afternoon, Evening, Night)
- `is_business_hours` (1 = 9 AM - 5 PM, 0 = outside)

**Records:** 96 (24 hours × 4 intervals per hour)

---

### 3. Dim_User

**Purpose:** User profile data  
**SCD Type:** Type 1 (overwrite changes)  
**Primary Key:** `user_key` (AUTOINCREMENT surrogate key)  
**Business Key:** `user_id`

**Attributes:**

- `username` (unique handle)
- `email`
- `location` (city/country)
- `bio` (user description)
- `account_created_date` (FK to Dim_Date)

**Records:** 15 users

---

### 4. Dim_Repository

**Purpose:** Repository metadata  
**SCD Type:** Type 1  
**Primary Key:** `repo_key` (AUTOINCREMENT surrogate key)  
**Business Key:** `repo_id`

**Attributes:**

- `repo_name`
- `repo_description`
- `visibility` (public, private, internal)
- `owner_type` (User, Organization)
- `owner_name` (denormalized for faster queries)
- `created_date` (FK to Dim_Date)

**Records:** 36 repositories

---

### 5. Dim_Organization

**Purpose:** Organization profile data  
**SCD Type:** Type 1  
**Primary Key:** `org_key` (AUTOINCREMENT surrogate key)  
**Business Key:** `org_id`

**Attributes:**

- `org_name`
- `org_description`
- `created_date` (FK to Dim_Date)

**Records:** 5 organizations

---

### 6. Dim_Status

**Purpose:** Status reference data  
**Primary Key:** `status_key` (AUTOINCREMENT)  
**Business Key:** `status_name`

**Attributes:**

- `status_name` (open, closed, merged, in_progress)
- `status_category` (grouping)
- `status_description`

**Records:** 4 statuses

---

## Fact Tables (3)

### 1. Fact_Commits

**Purpose:** Commit activity metrics  
**Grain:** One row per commit  
**Primary Key:** `commit_fact_key` (AUTOINCREMENT)

**Foreign Keys (Dimensions):**

- `commit_date_key` → Dim_Date (when committed)
- `commit_time_key` → Dim_Time (time of commit)
- `repo_key` → Dim_Repository (which repository)
- `author_key` → Dim_User (who committed)

**Degenerate Dimensions:**

- `commit_id` (original operational key)
- `commit_hash` (git SHA)

**Measures (Additive):**

- `message_length` (characters)
- `lines_added` (code added)
- `lines_deleted` (code removed)
- `files_changed` (files modified)
- `net_lines_changed` (GENERATED: lines_added - lines_deleted)

**Records:** 36 commits

**Analytical Questions:**

- _How many commits per day/week/month?_
- _Which repositories have the most commits?_
- _What time of day are developers most active?_
- _How much code is being added vs deleted?_

---

### 2. Fact_Issues

**Purpose:** Issue tracking and resolution metrics  
**Grain:** One row per issue  
**Primary Key:** `issue_fact_key` (AUTOINCREMENT)

**Foreign Keys (Dimensions):**

- `created_date_key` → Dim_Date (when opened)
- `closed_date_key` → Dim_Date (when closed, NULL if open)
- `repo_key` → Dim_Repository
- `author_key` → Dim_User (who reported)
- `status_key` → Dim_Status (current status)

**Degenerate Dimensions:**

- `issue_id` (original operational key)

**Measures:**

- `title_length` (characters)
- `description_length` (characters)
- `time_to_close_hours` (resolution time, NULL if open)

**Flags (Semi-Additive):**

- `is_open` (0/1)
- `is_closed` (0/1)

**Records:** 30 issues

**Analytical Questions:**

- _What's the average time to close an issue?_
- _How many open issues per repository?_
- _Which users report the most issues?_
- _Issue trends over time?_

---

### 3. Fact_PullRequests

**Purpose:** Pull request workflow and merge metrics  
**Grain:** One row per pull request  
**Primary Key:** `pr_fact_key` (AUTOINCREMENT)

**Foreign Keys (Dimensions):**

- `created_date_key` → Dim_Date (when opened)
- `merged_date_key` → Dim_Date (when merged, NULL if not merged)
- `closed_date_key` → Dim_Date (when closed without merge, NULL if not closed)
- `repo_key` → Dim_Repository
- `author_key` → Dim_User (who submitted)
- `status_key` → Dim_Status (current status)

**Degenerate Dimensions:**

- `pr_id` (original operational key)

**Measures:**

- `title_length` (characters)
- `time_to_merge_hours` (NULL if not merged)
- `time_to_close_hours` (NULL if not closed)

**Flags:**

- `is_open` (0/1)
- `is_merged` (0/1)
- `is_closed` (0/1)

**Records:** 30 pull requests

**Analytical Questions:**

- _What's the average time to merge a PR?_
- _How many PRs are merged vs closed without merge?_
- _Which developers have the most merged PRs?_
- _PR velocity trends?_

---

## ETL Process

### Data Flow

1. **Extract:** Read from operational tables (User, Repository, GitCommit, Issue, PullRequest, Organization)
2. **Transform:**
   - Convert dates to surrogate keys (YYYYMMDD format)
   - Round times to nearest 15-minute interval
   - Calculate derived metrics (time_to_close, net_lines_changed)
   - Join dimension tables to get surrogate keys
3. **Load:** Insert into fact tables with foreign keys to dimensions

### ETL Script

- **File:** `database/warehouse-etl.sql`
- **Frequency:** Run manually or schedule (incremental loads in production)
- **Data Quality:** Foreign keys enforce referential integrity

---

## Business Intelligence Use Cases

### 1. Developer Productivity Dashboard

- **Metrics:** Commits per developer, lines of code, PR merge rate
- **Dimensions:** Time (daily/weekly/monthly), User, Repository
- **Visualizations:** Line charts (trends), bar charts (top contributors)

### 2. Repository Health Report

- **Metrics:** Open issues count, average time to close, PR velocity
- **Dimensions:** Repository, Status, Time
- **Visualizations:** Scorecards, KPI gauges, trend lines

### 3. Activity Analysis

- **Metrics:** Commits by time of day, weekend vs weekday activity
- **Dimensions:** Time (hour), Date (is_weekend), User
- **Visualizations:** Heatmaps, time series charts
