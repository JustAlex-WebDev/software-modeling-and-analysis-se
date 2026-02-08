PRAGMA foreign_keys = ON;

-- =========================
-- TRIGGER 1: Repository Owner Validation
-- =========================
-- Makes sure repo has exactly one owner (user XOR org)
-- Fires before insert/update to check the constraint
-- This prevents invalid data from getting in

CREATE TRIGGER trg_repository_prevent_multiple_owners_insert
BEFORE INSERT ON Repository
FOR EACH ROW
WHEN (NEW.owner_user_id IS NOT NULL AND NEW.owner_org_id IS NOT NULL)
   OR (NEW.owner_user_id IS NULL AND NEW.owner_org_id IS NULL)
BEGIN
    SELECT RAISE(ABORT, 'Repository must have exactly one owner: either owner_user_id OR owner_org_id, not both or neither');
END;

CREATE TRIGGER trg_repository_prevent_multiple_owners_update
BEFORE UPDATE ON Repository
FOR EACH ROW
WHEN (NEW.owner_user_id IS NOT NULL AND NEW.owner_org_id IS NOT NULL)
   OR (NEW.owner_user_id IS NULL AND NEW.owner_org_id IS NULL)
BEGIN
    SELECT RAISE(ABORT, 'Repository must have exactly one owner: either owner_user_id OR owner_org_id, not both or neither');
END;

-- =========================
-- TRIGGER 2: Star Audit Logging
-- =========================
-- Keeps track of when users star/unstar repos
-- Useful for analyzing popularity trends later
-- Creates a separate audit table to log everything

-- Audit table for stars
CREATE TABLE IF NOT EXISTS Star_Audit (
    audit_id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL CHECK (action IN ('STAR_ADDED', 'STAR_REMOVED')),
    user_id INTEGER NOT NULL,
    repo_id INTEGER NOT NULL,
    action_timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_username TEXT,
    repo_name TEXT
);

-- Trigger for star additions
CREATE TRIGGER trg_star_audit_insert
AFTER INSERT ON Star
FOR EACH ROW
BEGIN
    INSERT INTO Star_Audit (action, user_id, repo_id, user_username, repo_name)
    SELECT 
        'STAR_ADDED',
        NEW.user_id,
        NEW.repo_id,
        u.username,
        r.name
    FROM User u, Repository r
    WHERE u.user_id = NEW.user_id 
      AND r.repo_id = NEW.repo_id;
END;

-- Trigger for star removals
CREATE TRIGGER trg_star_audit_delete
AFTER DELETE ON Star
FOR EACH ROW
BEGIN
    INSERT INTO Star_Audit (action, user_id, repo_id, user_username, repo_name)
    SELECT 
        'STAR_REMOVED',
        OLD.user_id,
        OLD.repo_id,
        u.username,
        r.name
    FROM User u, Repository r
    WHERE u.user_id = OLD.user_id 
      AND r.repo_id = OLD.repo_id;
END;

-- =========================
-- TRIGGER 3: Validate Pull Request Status Transitions
-- =========================
-- Purpose: Ensure valid PR status transitions (open → merged/closed only)
-- Type: BEFORE UPDATE validation trigger
-- Business Rule: Cannot reopen merged PRs, must follow workflow

CREATE TRIGGER trg_pullrequest_validate_status_transition
BEFORE UPDATE OF status ON PullRequest
FOR EACH ROW
WHEN OLD.status != NEW.status
BEGIN
    -- Cannot reopen a merged PR
    SELECT CASE
        WHEN OLD.status = 'merged' AND NEW.status IN ('open', 'closed') THEN
            RAISE(ABORT, 'Cannot reopen or close a merged pull request')
        -- Cannot merge a closed PR (must reopen first)
        WHEN OLD.status = 'closed' AND NEW.status = 'merged' THEN
            RAISE(ABORT, 'Cannot merge a closed pull request without reopening')
    END;
END;

-- =========================
-- TRIGGER 4: Auto-set Merged Timestamp
-- =========================
-- Purpose: Automatically set merged_at timestamp when PR is merged
-- Type: BEFORE UPDATE automation trigger
-- Business Value: Ensure data consistency

CREATE TRIGGER trg_pullrequest_set_merged_timestamp
BEFORE UPDATE OF status ON PullRequest
FOR EACH ROW
WHEN NEW.status = 'merged' AND OLD.status != 'merged'
BEGIN
    UPDATE PullRequest 
    SET merged_at = CURRENT_TIMESTAMP
    WHERE pr_id = NEW.pr_id;
END;

-- =========================
-- TRIGGER 5: Prevent Deletion of Active Repositories
-- =========================
-- Purpose: Prevent deletion of repositories with open issues or PRs
-- Type: BEFORE DELETE protection trigger
-- Business Rule: Must close all issues and PRs before deleting repo

CREATE TRIGGER trg_repository_prevent_deletion_with_active_content
BEFORE DELETE ON Repository
FOR EACH ROW
WHEN EXISTS (
    SELECT 1 FROM Issue WHERE repo_id = OLD.repo_id AND status = 'open'
) OR EXISTS (
    SELECT 1 FROM PullRequest WHERE repo_id = OLD.repo_id AND status = 'open'
)
BEGIN
    SELECT RAISE(ABORT, 'Cannot delete repository with open issues or pull requests. Close them first.');
END;

-- =========================
-- TRIGGER 6: Validate Commit Author
-- =========================
-- Purpose: Ensure commit author is a valid user
-- Type: BEFORE INSERT validation trigger
-- Business Rule: All commits must be authored by registered users

CREATE TRIGGER trg_commit_validate_author
BEFORE INSERT ON GitCommit
FOR EACH ROW
WHEN NOT EXISTS (SELECT 1 FROM User WHERE user_id = NEW.author_user_id)
BEGIN
    SELECT RAISE(ABORT, 'Commit author must be a registered user');
END;

-- =========================
-- TRIGGER 7: Prevent Duplicate Stars
-- =========================
-- Purpose: Additional validation to prevent duplicate stars
-- Type: BEFORE INSERT validation trigger
-- Note: Primary key already enforces this, but trigger provides better error message

CREATE TRIGGER trg_star_prevent_duplicates
BEFORE INSERT ON Star
FOR EACH ROW
WHEN EXISTS (
    SELECT 1 FROM Star 
    WHERE user_id = NEW.user_id 
      AND repo_id = NEW.repo_id
)
BEGIN
    SELECT RAISE(ABORT, 'User has already starred this repository');
END;

-- =========================
-- VERIFICATION
-- =========================
SELECT '✅ Database triggers created successfully!' AS status;

-- Show all triggers
SELECT 
    name as trigger_name,
    tbl_name as table_name,
    CASE 
        WHEN sql LIKE '%BEFORE INSERT%' THEN 'BEFORE INSERT'
        WHEN sql LIKE '%AFTER INSERT%' THEN 'AFTER INSERT'
        WHEN sql LIKE '%BEFORE UPDATE%' THEN 'BEFORE UPDATE'
        WHEN sql LIKE '%AFTER UPDATE%' THEN 'AFTER UPDATE'
        WHEN sql LIKE '%BEFORE DELETE%' THEN 'BEFORE DELETE'
        WHEN sql LIKE '%AFTER DELETE%' THEN 'AFTER DELETE'
    END as trigger_type
FROM sqlite_master 
WHERE type = 'trigger'
  AND name LIKE 'trg_%'
ORDER BY tbl_name, name;
