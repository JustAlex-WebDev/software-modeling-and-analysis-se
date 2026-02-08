PRAGMA foreign_keys = ON;

-- =========================
-- POPULATE DIMENSION TABLES
-- =========================

-- =========================
-- Dim_Date - Generate date dimension
-- =========================
-- Populate with dates from 2023-2026 (covers all sample data)
WITH RECURSIVE dates(date_val) AS (
    SELECT '2023-01-01'
    UNION ALL
    SELECT date(date_val, '+1 day')
    FROM dates
    WHERE date_val < '2026-12-31'
)
INSERT INTO Dim_Date (
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    week,
    day_of_year,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend
)
SELECT 
    CAST(strftime('%Y%m%d', date_val) AS INTEGER) as date_key,
    date_val as full_date,
    CAST(strftime('%Y', date_val) AS INTEGER) as year,
    CAST((strftime('%m', date_val) - 1) / 3 + 1 AS INTEGER) as quarter,
    CAST(strftime('%m', date_val) AS INTEGER) as month,
    CASE strftime('%m', date_val)
        WHEN '01' THEN 'January' WHEN '02' THEN 'February'
        WHEN '03' THEN 'March' WHEN '04' THEN 'April'
        WHEN '05' THEN 'May' WHEN '06' THEN 'June'
        WHEN '07' THEN 'July' WHEN '08' THEN 'August'
        WHEN '09' THEN 'September' WHEN '10' THEN 'October'
        WHEN '11' THEN 'November' WHEN '12' THEN 'December'
    END as month_name,
    CAST(strftime('%W', date_val) AS INTEGER) as week,
    CAST(strftime('%j', date_val) AS INTEGER) as day_of_year,
    CAST(strftime('%d', date_val) AS INTEGER) as day_of_month,
    CAST(strftime('%w', date_val) AS INTEGER) + 1 as day_of_week,
    CASE strftime('%w', date_val)
        WHEN '0' THEN 'Sunday' WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday' WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday' WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END as day_name,
    CASE WHEN strftime('%w', date_val) IN ('0', '6') THEN 1 ELSE 0 END as is_weekend
FROM dates;

-- =========================
-- Dim_Time - Generate time dimension
-- =========================
INSERT INTO Dim_Time (time_key, hour, minute, time_period, is_business_hours)
WITH RECURSIVE times(h, m) AS (
    SELECT 0, 0
    UNION ALL
    SELECT 
        CASE WHEN m = 45 THEN h + 1 ELSE h END,
        CASE WHEN m = 45 THEN 0 ELSE m + 15 END
    FROM times
    WHERE h < 23 OR (h = 23 AND m < 45)
)
SELECT 
    h * 100 + m as time_key,
    h as hour,
    m as minute,
    CASE 
        WHEN h >= 6 AND h < 12 THEN 'Morning'
        WHEN h >= 12 AND h < 17 THEN 'Afternoon'
        WHEN h >= 17 AND h < 21 THEN 'Evening'
        ELSE 'Night'
    END as time_period,
    CASE WHEN h >= 9 AND h < 17 THEN 1 ELSE 0 END as is_business_hours
FROM times;

-- =========================
-- Dim_User - Load from User table
-- =========================
INSERT INTO Dim_User (
    user_id,
    username,
    email,
    location,
    bio,
    account_created_date
)
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.location,
    u.bio,
    CAST(strftime('%Y%m%d', u.created_at) AS INTEGER) as account_created_date
FROM User u;

-- =========================
-- Dim_Repository - Load from Repository table
-- =========================
INSERT INTO Dim_Repository (
    repo_id,
    repo_name,
    repo_description,
    visibility,
    owner_type,
    owner_name,
    created_date
)
SELECT 
    r.repo_id,
    r.name,
    r.description,
    r.visibility,
    CASE 
        WHEN r.owner_user_id IS NOT NULL THEN 'User'
        ELSE 'Organization'
    END as owner_type,
    COALESCE(u.username, o.name) as owner_name,
    CAST(strftime('%Y%m%d', r.created_at) AS INTEGER) as created_date
FROM Repository r
LEFT JOIN User u ON r.owner_user_id = u.user_id
LEFT JOIN Organization o ON r.owner_org_id = o.org_id;

-- =========================
-- Dim_Organization - Load from Organization table
-- =========================
INSERT INTO Dim_Organization (
    org_id,
    org_name,
    org_description,
    created_date
)
SELECT 
    o.org_id,
    o.name,
    o.description,
    CAST(strftime('%Y%m%d', o.created_at) AS INTEGER) as created_date
FROM Organization o;

-- =========================
-- Dim_Status - Load static status values
-- =========================
INSERT INTO Dim_Status (status_name, status_category, status_description) VALUES
('open', 'open', 'Item is currently open and active'),
('closed', 'closed', 'Item has been closed without merging'),
('merged', 'merged', 'Pull request has been successfully merged'),
('in_progress', 'in_progress', 'Item is being actively worked on');

-- =========================
-- POPULATE FACT TABLES
-- =========================

-- =========================
-- Fact_Commits - Load commit metrics
-- =========================
INSERT INTO Fact_Commits (
    commit_date_key,
    commit_time_key,
    repo_key,
    author_key,
    commit_id,
    commit_hash,
    message_length,
    lines_added,
    lines_deleted,
    files_changed
)
SELECT 
    CAST(strftime('%Y%m%d', c.committed_at) AS INTEGER) as commit_date_key,
    CAST(strftime('%H', c.committed_at) AS INTEGER) * 100 + 
        (CAST(strftime('%M', c.committed_at) AS INTEGER) / 15) * 15 as commit_time_key,
    dr.repo_key,
    du.user_key,
    c.commit_id,
    c.commit_hash,
    length(c.message) as message_length,
    -- Simulated metrics (in real system, would parse git diff)
    abs(random() % 100) + 1 as lines_added,
    abs(random() % 50) as lines_deleted,
    abs(random() % 5) + 1 as files_changed
FROM GitCommit c
JOIN Dim_Repository dr ON c.repo_id = dr.repo_id
JOIN Dim_User du ON c.author_user_id = du.user_id;

-- =========================
-- Fact_Issues - Load issue metrics
-- =========================
INSERT INTO Fact_Issues (
    created_date_key,
    closed_date_key,
    repo_key,
    author_key,
    status_key,
    issue_id,
    title_length,
    description_length,
    time_to_close_hours,
    is_open,
    is_closed
)
SELECT 
    CAST(strftime('%Y%m%d', i.created_at) AS INTEGER) as created_date_key,
    CASE 
        WHEN i.status = 'closed' 
        THEN CAST(strftime('%Y%m%d', datetime(i.created_at, '+' || (abs(random() % 168) + 1) || ' hours')) AS INTEGER)
        ELSE NULL 
    END as closed_date_key,
    dr.repo_key,
    du.user_key,
    ds.status_key,
    i.issue_id,
    length(i.title) as title_length,
    length(i.description) as description_length,
    CASE 
        WHEN i.status = 'closed' 
        THEN abs(random() % 168) + 1
        ELSE NULL 
    END as time_to_close_hours,
    CASE WHEN i.status = 'open' THEN 1 ELSE 0 END as is_open,
    CASE WHEN i.status = 'closed' THEN 1 ELSE 0 END as is_closed
FROM Issue i
JOIN Dim_Repository dr ON i.repo_id = dr.repo_id
JOIN Dim_User du ON i.author_user_id = du.user_id
JOIN Dim_Status ds ON i.status = ds.status_name;

-- =========================
-- Fact_PullRequests - Load PR metrics
-- =========================
INSERT INTO Fact_PullRequests (
    created_date_key,
    merged_date_key,
    closed_date_key,
    repo_key,
    author_key,
    status_key,
    pr_id,
    title_length,
    time_to_merge_hours,
    time_to_close_hours,
    is_open,
    is_merged,
    is_closed
)
SELECT 
    CAST(strftime('%Y%m%d', pr.created_at) AS INTEGER) as created_date_key,
    CASE 
        WHEN pr.merged_at IS NOT NULL 
        THEN CAST(strftime('%Y%m%d', pr.merged_at) AS INTEGER)
        ELSE NULL 
    END as merged_date_key,
    CASE 
        WHEN pr.status = 'closed' AND pr.merged_at IS NULL
        THEN CAST(strftime('%Y%m%d', datetime(pr.created_at, '+' || (abs(random() % 72) + 1) || ' hours')) AS INTEGER)
        ELSE NULL 
    END as closed_date_key,
    dr.repo_key,
    du.user_key,
    ds.status_key,
    pr.pr_id,
    length(pr.title) as title_length,
    CASE 
        WHEN pr.merged_at IS NOT NULL 
        THEN CAST((julianday(pr.merged_at) - julianday(pr.created_at)) * 24 AS INTEGER)
        ELSE NULL 
    END as time_to_merge_hours,
    CASE 
        WHEN pr.status = 'closed' AND pr.merged_at IS NULL
        THEN abs(random() % 72) + 1
        ELSE NULL 
    END as time_to_close_hours,
    CASE WHEN pr.status = 'open' THEN 1 ELSE 0 END as is_open,
    CASE WHEN pr.status = 'merged' THEN 1 ELSE 0 END as is_merged,
    CASE WHEN pr.status = 'closed' THEN 1 ELSE 0 END as is_closed
FROM PullRequest pr
JOIN Dim_Repository dr ON pr.repo_id = dr.repo_id
JOIN Dim_User du ON pr.author_user_id = du.user_id
JOIN Dim_Status ds ON pr.status = ds.status_name;

-- =========================
-- VERIFICATION
-- =========================
SELECT '✅ Data Warehouse populated successfully!' AS status;

SELECT 'Dim_Date records: ' || COUNT(*) FROM Dim_Date;
SELECT 'Dim_Time records: ' || COUNT(*) FROM Dim_Time;
SELECT 'Dim_User records: ' || COUNT(*) FROM Dim_User;
SELECT 'Dim_Repository records: ' || COUNT(*) FROM Dim_Repository;
SELECT 'Dim_Organization records: ' || COUNT(*) FROM Dim_Organization;
SELECT 'Dim_Status records: ' || COUNT(*) FROM Dim_Status;
SELECT 'Fact_Commits records: ' || COUNT(*) FROM Fact_Commits;
SELECT 'Fact_Issues records: ' || COUNT(*) FROM Fact_Issues;
SELECT 'Fact_PullRequests records: ' || COUNT(*) FROM Fact_PullRequests;
