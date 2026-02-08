PRAGMA foreign_keys = ON;

-- =========================
-- USER TABLE
-- =========================
-- This stores all the GitHub users
-- Primary key is user_id (auto-generated)
-- Made sure username and email are unique
CREATE TABLE User (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    bio TEXT,
    location TEXT,
    
    CHECK(length(username) <= 50),
    CHECK(length(email) <= 255),
    CHECK(length(bio) <= 500),
    CHECK(length(location) <= 100)
);

-- =========================
-- ORGANIZATION TABLE
-- =========================
-- For GitHub orgs like Mozilla, Google, etc.
-- Each org gets unique ID
-- Name has to be unique obviously
CREATE TABLE Organization (
    org_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CHECK(length(name) <= 100),
    CHECK(length(description) <= 500)
);

-- =========================
-- REPOSITORY TABLE
-- =========================
-- Code repositories (projects)
-- Important: repo can be owned by EITHER a user OR an org, not both!
-- This was tricky to implement with the CHECK constraint below
CREATE TABLE Repository (
    repo_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    visibility TEXT NOT NULL CHECK (visibility IN ('public', 'private')),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- These FKs are nullable because only one will be set
    owner_user_id INTEGER,
    owner_org_id INTEGER,
    
    -- Link to User or Organization tables
    FOREIGN KEY (owner_user_id) REFERENCES User(user_id) ON DELETE CASCADE,
    FOREIGN KEY (owner_org_id) REFERENCES Organization(org_id) ON DELETE CASCADE,
    
    -- XOR constraint - one owner only!
    CHECK (
        (owner_user_id IS NOT NULL AND owner_org_id IS NULL)
        OR
        (owner_user_id IS NULL AND owner_org_id IS NOT NULL)
    ),
    
    CHECK(length(name) <= 100),
    CHECK(length(description) <= 500)
);

-- =========================
-- COMMIT TABLE
-- =========================
-- Represents a commit made to a repository
-- Key: commit_id (auto-increment)
-- Relationships: belongs to one repository, authored by one user
-- Note: Using "GitCommit" because "Commit" is a reserved word in SQLite
CREATE TABLE GitCommit (
    commit_id INTEGER PRIMARY KEY AUTOINCREMENT,
    commit_hash TEXT NOT NULL UNIQUE,
    message TEXT,
    committed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign keys (NOT NULL = total participation)
    repo_id INTEGER NOT NULL,
    author_user_id INTEGER NOT NULL,
    
    -- Foreign key constraints
    FOREIGN KEY (repo_id) REFERENCES Repository(repo_id) ON DELETE CASCADE,
    FOREIGN KEY (author_user_id) REFERENCES User(user_id) ON DELETE CASCADE,
    
    CHECK(length(commit_hash) <= 64),
    CHECK(length(message) <= 500)
);

-- =========================
-- ISSUE TABLE
-- =========================
-- Represents an issue (bug report or feature request) in a repository
-- Key: issue_id (auto-increment)
-- Relationships: belongs to one repository, created by one user
CREATE TABLE Issue (
    issue_id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL CHECK (status IN ('open', 'closed')),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign keys (NOT NULL = total participation)
    repo_id INTEGER NOT NULL,
    author_user_id INTEGER NOT NULL,
    
    -- Foreign key constraints
    FOREIGN KEY (repo_id) REFERENCES Repository(repo_id) ON DELETE CASCADE,
    FOREIGN KEY (author_user_id) REFERENCES User(user_id) ON DELETE CASCADE,
    
    CHECK(length(title) <= 200),
    CHECK(length(description) <= 1000)
);

-- =========================
-- PULL REQUEST TABLE
-- =========================
-- Represents a pull request proposing changes to a repository
-- Key: pr_id (auto-increment)
-- Relationships: belongs to one repository, created by one user
CREATE TABLE PullRequest (
    pr_id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('open', 'merged', 'closed')),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    merged_at DATETIME,
    
    -- Foreign keys (NOT NULL = total participation)
    repo_id INTEGER NOT NULL,
    author_user_id INTEGER NOT NULL,
    
    -- Foreign key constraints
    FOREIGN KEY (repo_id) REFERENCES Repository(repo_id) ON DELETE CASCADE,
    FOREIGN KEY (author_user_id) REFERENCES User(user_id) ON DELETE CASCADE,
    
    CHECK(length(title) <= 200)
);

-- =========================
-- STAR TABLE (Associative Entity)
-- =========================
-- Represents the many-to-many relationship between Users and Repositories
-- Composite Primary Key: (user_id, repo_id)
-- A user can star many repositories, a repository can be starred by many users
CREATE TABLE Star (
    user_id INTEGER NOT NULL,
    repo_id INTEGER NOT NULL,
    starred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Composite primary key
    PRIMARY KEY (user_id, repo_id),
    
    -- Foreign key constraints
    FOREIGN KEY (user_id) REFERENCES User(user_id) ON DELETE CASCADE,
    FOREIGN KEY (repo_id) REFERENCES Repository(repo_id) ON DELETE CASCADE
);

-- =========================
-- INDEXES FOR PERFORMANCE
-- =========================
-- Create indexes on foreign keys for faster queries

-- Repository owner indexes
CREATE INDEX idx_repository_owner_user ON Repository(owner_user_id);
CREATE INDEX idx_repository_owner_org ON Repository(owner_org_id);

-- Commit indexes
CREATE INDEX idx_commit_repo ON GitCommit(repo_id);
CREATE INDEX idx_commit_author ON GitCommit(author_user_id);
CREATE INDEX idx_commit_hash ON GitCommit(commit_hash);

-- Issue indexes
CREATE INDEX idx_issue_repo ON Issue(repo_id);
CREATE INDEX idx_issue_author ON Issue(author_user_id);
CREATE INDEX idx_issue_status ON Issue(status);

-- Pull Request indexes
CREATE INDEX idx_pr_repo ON PullRequest(repo_id);
CREATE INDEX idx_pr_author ON PullRequest(author_user_id);
CREATE INDEX idx_pr_status ON PullRequest(status);

-- Star indexes
CREATE INDEX idx_star_user ON Star(user_id);
CREATE INDEX idx_star_repo ON Star(repo_id);

-- =========================
-- VERIFICATION
-- =========================
-- Query to verify all tables were created
SELECT 'Database schema created successfully!' AS status;

SELECT name AS table_name
FROM sqlite_master
WHERE type = 'table'
  AND name NOT LIKE 'sqlite_%'
ORDER BY name;
