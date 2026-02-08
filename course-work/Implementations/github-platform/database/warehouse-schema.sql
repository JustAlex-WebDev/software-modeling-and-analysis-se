-- What this warehouse does:
-- - Analyze repo activity over time
-- - Track who's contributing what
-- - Look at trends (commits per month, etc)
-- - Calculate various metrics for reports

PRAGMA foreign_keys = ON;

-- =========================
-- DIMENSION TABLES
-- =========================

-- =========================
-- DIM_DATE - Date dimension table
-- =========================
-- This is super important for time-based analysis
CREATE TABLE Dim_Date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    month INTEGER NOT NULL,
    month_name TEXT NOT NULL,
    week INTEGER NOT NULL,
    day_of_year INTEGER NOT NULL,
    day_of_month INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_name TEXT NOT NULL,
    is_weekend INTEGER NOT NULL,
    is_holiday INTEGER DEFAULT 0,
    
    CHECK(quarter BETWEEN 1 AND 4),
    CHECK(month BETWEEN 1 AND 12),
    CHECK(day_of_week BETWEEN 1 AND 7),
    CHECK(is_weekend IN (0, 1)),
    CHECK(is_holiday IN (0, 1))
);

-- =========================
-- DIM_USER - User dimension (SCD Type 1)
-- =========================
CREATE TABLE Dim_User (
    user_key INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    location TEXT,
    bio TEXT,
    account_created_date INTEGER,
    
    -- Metadata
    valid_from DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_to DATETIME,
    is_current INTEGER NOT NULL DEFAULT 1,
    
    FOREIGN KEY (user_id) REFERENCES User(user_id),
    FOREIGN KEY (account_created_date) REFERENCES Dim_Date(date_key),
    CHECK(is_current IN (0, 1))
);

-- =========================
-- DIM_REPOSITORY - Repository dimension
-- =========================
CREATE TABLE Dim_Repository (
    repo_key INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_id INTEGER NOT NULL UNIQUE,
    repo_name TEXT NOT NULL,
    repo_description TEXT,
    visibility TEXT NOT NULL,
    owner_type TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    created_date INTEGER,
    
    -- Metadata
    valid_from DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_current INTEGER NOT NULL DEFAULT 1,
    
    FOREIGN KEY (repo_id) REFERENCES Repository(repo_id),
    FOREIGN KEY (created_date) REFERENCES Dim_Date(date_key),
    CHECK(visibility IN ('public', 'private')),
    CHECK(owner_type IN ('User', 'Organization')),
    CHECK(is_current IN (0, 1))
);

-- =========================
-- DIM_ORGANIZATION - Organization dimension
-- =========================
CREATE TABLE Dim_Organization (
    org_key INTEGER PRIMARY KEY AUTOINCREMENT,
    org_id INTEGER NOT NULL UNIQUE,
    org_name TEXT NOT NULL,
    org_description TEXT,
    created_date INTEGER,
    
    -- Metadata
    valid_from DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_current INTEGER NOT NULL DEFAULT 1,
    
    FOREIGN KEY (org_id) REFERENCES Organization(org_id),
    FOREIGN KEY (created_date) REFERENCES Dim_Date(date_key),
    CHECK(is_current IN (0, 1))
);

-- =========================
-- DIM_STATUS - Status dimension (for issues and PRs)
-- =========================
CREATE TABLE Dim_Status (
    status_key INTEGER PRIMARY KEY AUTOINCREMENT,
    status_name TEXT NOT NULL UNIQUE,
    status_category TEXT NOT NULL,
    status_description TEXT,
    
    CHECK(status_category IN ('open', 'closed', 'merged', 'in_progress'))
);

-- =========================
-- DIM_TIME - Time of day dimension
-- =========================
CREATE TABLE Dim_Time (
    time_key INTEGER PRIMARY KEY,
    hour INTEGER NOT NULL,
    minute INTEGER NOT NULL,
    time_period TEXT NOT NULL,
    is_business_hours INTEGER NOT NULL,
    
    CHECK(hour BETWEEN 0 AND 23),
    CHECK(minute BETWEEN 0 AND 59),
    CHECK(time_period IN ('Morning', 'Afternoon', 'Evening', 'Night')),
    CHECK(is_business_hours IN (0, 1))
);

-- =========================
-- FACT TABLES
-- =========================

-- =========================
-- FACT_COMMITS - Commit activity fact table
-- =========================
CREATE TABLE Fact_Commits (
    commit_fact_key INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Dimension keys
    commit_date_key INTEGER NOT NULL,
    commit_time_key INTEGER NOT NULL,
    repo_key INTEGER NOT NULL,
    author_key INTEGER NOT NULL,
    
    -- Degenerate dimensions (high cardinality attributes)
    commit_id INTEGER NOT NULL,
    commit_hash TEXT NOT NULL,
    
    -- Measures (facts)
    message_length INTEGER NOT NULL,
    lines_added INTEGER DEFAULT 0,
    lines_deleted INTEGER DEFAULT 0,
    files_changed INTEGER DEFAULT 1,
    
    -- Derived measures
    net_lines_changed INTEGER GENERATED ALWAYS AS (lines_added - lines_deleted) STORED,
    
    -- Metadata
    etl_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (commit_date_key) REFERENCES Dim_Date(date_key),
    FOREIGN KEY (commit_time_key) REFERENCES Dim_Time(time_key),
    FOREIGN KEY (repo_key) REFERENCES Dim_Repository(repo_key),
    FOREIGN KEY (author_key) REFERENCES Dim_User(user_key),
    FOREIGN KEY (commit_id) REFERENCES GitCommit(commit_id)
);

-- =========================
-- FACT_ISSUES - Issue tracking fact table
-- =========================
CREATE TABLE Fact_Issues (
    issue_fact_key INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Dimension keys
    created_date_key INTEGER NOT NULL,
    closed_date_key INTEGER,
    repo_key INTEGER NOT NULL,
    author_key INTEGER NOT NULL,
    status_key INTEGER NOT NULL,
    
    -- Degenerate dimensions
    issue_id INTEGER NOT NULL,
    
    -- Measures (facts)
    title_length INTEGER NOT NULL,
    description_length INTEGER,
    time_to_close_hours INTEGER,
    
    -- Semi-additive measures
    is_open INTEGER NOT NULL,
    is_closed INTEGER NOT NULL,
    
    -- Metadata
    etl_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (created_date_key) REFERENCES Dim_Date(date_key),
    FOREIGN KEY (closed_date_key) REFERENCES Dim_Date(date_key),
    FOREIGN KEY (repo_key) REFERENCES Dim_Repository(repo_key),
    FOREIGN KEY (author_key) REFERENCES Dim_User(user_key),
    FOREIGN KEY (status_key) REFERENCES Dim_Status(status_key),
    FOREIGN KEY (issue_id) REFERENCES Issue(issue_id),
    
    CHECK(is_open IN (0, 1)),
    CHECK(is_closed IN (0, 1))
);

-- =========================
-- FACT_PULL_REQUESTS - Pull request fact table
-- =========================
CREATE TABLE Fact_PullRequests (
    pr_fact_key INTEGER PRIMARY KEY AUTOINCREMENT,
    
    -- Dimension keys
    created_date_key INTEGER NOT NULL,
    merged_date_key INTEGER,
    closed_date_key INTEGER,
    repo_key INTEGER NOT NULL,
    author_key INTEGER NOT NULL,
    status_key INTEGER NOT NULL,
    
    -- Degenerate dimensions
    pr_id INTEGER NOT NULL,
    
    -- Measures (facts)
    title_length INTEGER NOT NULL,
    time_to_merge_hours INTEGER,
    time_to_close_hours INTEGER,
    
    -- Semi-additive measures
    is_open INTEGER NOT NULL,
    is_merged INTEGER NOT NULL,
    is_closed INTEGER NOT NULL,
    
    -- Metadata
    etl_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (created_date_key) REFERENCES Dim_Date(date_key),
    FOREIGN KEY (merged_date_key) REFERENCES Dim_Date(date_key),
    FOREIGN KEY (closed_date_key) REFERENCES Dim_Date(date_key),
    FOREIGN KEY (repo_key) REFERENCES Dim_Repository(repo_key),
    FOREIGN KEY (author_key) REFERENCES Dim_User(user_key),
    FOREIGN KEY (status_key) REFERENCES Dim_Status(status_key),
    FOREIGN KEY (pr_id) REFERENCES PullRequest(pr_id),
    
    CHECK(is_open IN (0, 1)),
    CHECK(is_merged IN (0, 1)),
    CHECK(is_closed IN (0, 1))
);

-- =========================
-- INDEXES FOR WAREHOUSE QUERIES
-- =========================

-- Dimension indexes
CREATE INDEX idx_dim_date_full_date ON Dim_Date(full_date);
CREATE INDEX idx_dim_date_year_month ON Dim_Date(year, month);
CREATE INDEX idx_dim_user_user_id ON Dim_User(user_id);
CREATE INDEX idx_dim_repo_repo_id ON Dim_Repository(repo_id);
CREATE INDEX idx_dim_org_org_id ON Dim_Organization(org_id);

-- Fact table indexes (composite keys for common queries)
CREATE INDEX idx_fact_commits_date_repo ON Fact_Commits(commit_date_key, repo_key);
CREATE INDEX idx_fact_commits_author ON Fact_Commits(author_key);
CREATE INDEX idx_fact_issues_date_repo ON Fact_Issues(created_date_key, repo_key);
CREATE INDEX idx_fact_issues_status ON Fact_Issues(status_key);
CREATE INDEX idx_fact_prs_date_repo ON Fact_PullRequests(created_date_key, repo_key);
CREATE INDEX idx_fact_prs_status ON Fact_PullRequests(status_key);

-- =========================
-- VERIFICATION
-- =========================
SELECT '✅ Data Warehouse schema created successfully!' AS status;

SELECT 'Dimension Tables: ' || COUNT(*) AS info 
FROM sqlite_master 
WHERE type='table' AND name LIKE 'Dim_%';

SELECT 'Fact Tables: ' || COUNT(*) AS info 
FROM sqlite_master 
WHERE type='table' AND name LIKE 'Fact_%';
