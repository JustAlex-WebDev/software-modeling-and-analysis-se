-- =========================
-- VIEW 1: Repository Stats
-- =========================
-- Shows all important stats for each repo
-- Counts stars, commits, issues, and pull requests
-- Pretty useful for the Power BI dashboard later

create view vw_repositorystats as
   select r.repo_id,
          r.name as repository_name,
          r.visibility,
          r.created_at,
    
    -- Owner information
          coalesce(
             u.username,
             o.name
          ) as owner_name,
          case
             when r.owner_user_id is not null then
                'User'
             else
                'Organization'
          end as owner_type,
    
    -- Statistics
          coalesce(
             star_counts.star_count,
             0
          ) as total_stars,
          coalesce(
             commit_counts.commit_count,
             0
          ) as total_commits,
          coalesce(
             issue_counts.total_issues,
             0
          ) as total_issues,
          coalesce(
             issue_counts.open_issues,
             0
          ) as open_issues,
          coalesce(
             issue_counts.closed_issues,
             0
          ) as closed_issues,
          coalesce(
             pr_counts.total_prs,
             0
          ) as total_pull_requests,
          coalesce(
             pr_counts.open_prs,
             0
          ) as open_pull_requests,
          coalesce(
             pr_counts.merged_prs,
             0
          ) as merged_pull_requests,
          coalesce(
             pr_counts.closed_prs,
             0
          ) as closed_pull_requests,
    
    -- Activity indicators
          coalesce(
             commit_counts.last_commit_date,
             r.created_at
          ) as last_commit_date,
          julianday('now') - julianday(coalesce(
             commit_counts.last_commit_date,
             r.created_at
          )) as days_since_last_commit
     from repository r
     left join user u
   on r.owner_user_id = u.user_id
     left join organization o
   on r.owner_org_id = o.org_id

-- Star counts
     left join (
      select repo_id,
             count(*) as star_count
        from star
       group by repo_id
   ) star_counts
   on r.repo_id = star_counts.repo_id

-- Commit counts
     left join (
      select repo_id,
             count(*) as commit_count,
             max(committed_at) as last_commit_date
        from gitcommit
       group by repo_id
   ) commit_counts
   on r.repo_id = commit_counts.repo_id

-- Issue counts
     left join (
      select repo_id,
             count(*) as total_issues,
             sum(
                case
                   when status = 'open' then
                      1
                   else
                      0
                end
             ) as open_issues,
             sum(
                case
                   when status = 'closed' then
                      1
                   else
                      0
                end
             ) as closed_issues
        from issue
       group by repo_id
   ) issue_counts
   on r.repo_id = issue_counts.repo_id

-- PR counts
     left join (
      select repo_id,
             count(*) as total_prs,
             sum(
                case
                   when status = 'open' then
                      1
                   else
                      0
                end
             ) as open_prs,
             sum(
                case
                   when status = 'merged' then
                      1
                   else
                      0
                end
             ) as merged_prs,
             sum(
                case
                   when status = 'closed' then
                      1
                   else
                      0
                end
             ) as closed_prs
        from pullrequest
       group by repo_id
   ) pr_counts
   on r.repo_id = pr_counts.repo_id;

-- =========================
-- VIEW 2: User Activity Summary
-- =========================
-- Purpose: Complete activity profile for each user
-- Replaces: fn_GetUserActivity() function
-- Returns: All user contributions and engagement metrics

create view vw_useractivity as
   select u.user_id,
          u.username,
          u.email,
          u.location,
          u.created_at as user_since,
    
    -- Repository ownership
          coalesce(
             repo_counts.owned_repos,
             0
          ) as repositories_owned,
          coalesce(
             repo_counts.public_repos,
             0
          ) as public_repositories,
          coalesce(
             repo_counts.private_repos,
             0
          ) as private_repositories,
    
    -- Contribution metrics
          coalesce(
             commit_counts.total_commits,
             0
          ) as total_commits,
          coalesce(
             commit_counts.repos_contributed_to,
             0
          ) as repositories_contributed_to,
          coalesce(
             commit_counts.last_commit_date,
             u.created_at
          ) as last_commit_date,
    
    -- Issue activity
          coalesce(
             issue_counts.issues_created,
             0
          ) as issues_created,
          coalesce(
             issue_counts.open_issues_created,
             0
          ) as open_issues_created,
    
    -- Pull request activity
          coalesce(
             pr_counts.prs_created,
             0
          ) as pull_requests_created,
          coalesce(
             pr_counts.prs_merged,
             0
          ) as pull_requests_merged,
          coalesce(
             pr_counts.prs_open,
             0
          ) as pull_requests_open,
    
    -- Engagement
          coalesce(
             star_counts.repos_starred,
             0
          ) as repositories_starred,
    
    -- Activity score (weighted metric)
          ( coalesce(
             commit_counts.total_commits,
             0
          ) * 1.0 + coalesce(
             pr_counts.prs_merged,
             0
          ) * 3.0 + coalesce(
             issue_counts.issues_created,
             0
          ) * 0.5 + coalesce(
             star_counts.repos_starred,
             0
          ) * 0.2 ) as activity_score
     from user u

-- Repository ownership
     left join (
      select owner_user_id,
             count(*) as owned_repos,
             sum(
                case
                   when visibility = 'public' then
                      1
                   else
                      0
                end
             ) as public_repos,
             sum(
                case
                   when visibility = 'private' then
                      1
                   else
                      0
                end
             ) as private_repos
        from repository
       where owner_user_id is not null
       group by owner_user_id
   ) repo_counts
   on u.user_id = repo_counts.owner_user_id

-- Commit statistics
     left join (
      select author_user_id,
             count(*) as total_commits,
             count(distinct repo_id) as repos_contributed_to,
             max(committed_at) as last_commit_date
        from gitcommit
       group by author_user_id
   ) commit_counts
   on u.user_id = commit_counts.author_user_id

-- Issue statistics
     left join (
      select author_user_id,
             count(*) as issues_created,
             sum(
                case
                   when status = 'open' then
                      1
                   else
                      0
                end
             ) as open_issues_created
        from issue
       group by author_user_id
   ) issue_counts
   on u.user_id = issue_counts.author_user_id

-- Pull request statistics
     left join (
      select author_user_id,
             count(*) as prs_created,
             sum(
                case
                   when status = 'merged' then
                      1
                   else
                      0
                end
             ) as prs_merged,
             sum(
                case
                   when status = 'open' then
                      1
                   else
                      0
                end
             ) as prs_open
        from pullrequest
       group by author_user_id
   ) pr_counts
   on u.user_id = pr_counts.author_user_id

-- Star statistics
     left join (
      select user_id,
             count(*) as repos_starred
        from star
       group by user_id
   ) star_counts
   on u.user_id = star_counts.user_id;

-- =========================
-- VIEW 3: Active Repositories
-- =========================
-- Purpose: Recently active repositories with recent activity
-- Replaces: usp_GetActiveRepositories() procedure
-- Returns: Repositories with activity in last 90 days

create view vw_activerepositories as
   select r.repo_id,
          r.name as repository_name,
          r.visibility,
          coalesce(
             u.username,
             o.name
          ) as owner_name,
    
    -- Recent activity metrics
          coalesce(
             recent_commits.commit_count,
             0
          ) as recent_commits,
          coalesce(
             recent_issues.issue_count,
             0
          ) as recent_issues,
          coalesce(
             recent_prs.pr_count,
             0
          ) as recent_pull_requests,
          coalesce(
             recent_stars.star_count,
             0
          ) as recent_stars,
    
    -- Total activity score
          ( coalesce(
             recent_commits.commit_count,
             0
          ) + coalesce(
             recent_issues.issue_count,
             0
          ) + coalesce(
             recent_prs.pr_count,
             0
          ) + coalesce(
             recent_stars.star_count,
             0
          ) ) as total_recent_activity,
    
    -- Latest activity timestamp
          max(coalesce(
             recent_commits.last_activity,
             '1970-01-01'
          ),
              coalesce(
             recent_issues.last_activity,
             '1970-01-01'
          ),
              coalesce(
             recent_prs.last_activity,
             '1970-01-01'
          ),
              coalesce(
             recent_stars.last_activity,
             '1970-01-01'
          )) as last_activity_date
     from repository r
     left join user u
   on r.owner_user_id = u.user_id
     left join organization o
   on r.owner_org_id = o.org_id

-- Recent commits (last 90 days)
     left join (
      select repo_id,
             count(*) as commit_count,
             max(committed_at) as last_activity
        from gitcommit
       where committed_at >= datetime(
         'now',
         '-90 days'
      )
       group by repo_id
   ) recent_commits
   on r.repo_id = recent_commits.repo_id

-- Recent issues (last 90 days)
     left join (
      select repo_id,
             count(*) as issue_count,
             max(created_at) as last_activity
        from issue
       where created_at >= datetime(
         'now',
         '-90 days'
      )
       group by repo_id
   ) recent_issues
   on r.repo_id = recent_issues.repo_id

-- Recent PRs (last 90 days)
     left join (
      select repo_id,
             count(*) as pr_count,
             max(created_at) as last_activity
        from pullrequest
       where created_at >= datetime(
         'now',
         '-90 days'
      )
       group by repo_id
   ) recent_prs
   on r.repo_id = recent_prs.repo_id

-- Recent stars (last 90 days)
     left join (
      select repo_id,
             count(*) as star_count,
             max(starred_at) as last_activity
        from star
       where starred_at >= datetime(
         'now',
         '-90 days'
      )
       group by repo_id
   ) recent_stars
   on r.repo_id = recent_stars.repo_id
    where ( coalesce(
      recent_commits.commit_count,
      0
   ) + coalesce(
      recent_issues.issue_count,
      0
   ) + coalesce(
      recent_prs.pr_count,
      0
   ) + coalesce(
      recent_stars.star_count,
      0
   ) ) > 0;

-- =========================
-- VIEW 4: Top Contributors
-- =========================
-- Purpose: Leaderboard of most active contributors
-- Replaces: fn_GetTopContributors() function
-- Returns: Users ranked by contribution activity

create view vw_topcontributors as
   select u.user_id,
          u.username,
          u.location,
    
    -- Contribution counts
          coalesce(
             c.total_commits,
             0
          ) as total_commits,
          coalesce(
             pr.prs_merged,
             0
          ) as pull_requests_merged,
          coalesce(
             i.issues_created,
             0
          ) as issues_created,
          coalesce(
             c.repos_contributed,
             0
          ) as repositories_contributed_to,
    
    -- Weighted contribution score
          ( coalesce(
             c.total_commits,
             0
          ) * 2.0 + coalesce(
             pr.prs_merged,
             0
          ) * 5.0 + coalesce(
             i.issues_created,
             0
          ) * 1.0 ) as contribution_score,
    
    -- Ranking
          dense_rank()
          over(
              order by(coalesce(
                c.total_commits,
                0
             ) * 2.0 + coalesce(
                pr.prs_merged,
                0
             ) * 5.0 + coalesce(
                i.issues_created,
                0
             ) * 1.0) desc
          ) as contributor_rank
     from user u
     left join (
      select author_user_id,
             count(*) as total_commits,
             count(distinct repo_id) as repos_contributed
        from gitcommit
       group by author_user_id
   ) c
   on u.user_id = c.author_user_id
     left join (
      select author_user_id,
             count(*) as prs_merged
        from pullrequest
       where status = 'merged'
       group by author_user_id
   ) pr
   on u.user_id = pr.author_user_id
     left join (
      select author_user_id,
             count(*) as issues_created
        from issue
       group by author_user_id
   ) i
   on u.user_id = i.author_user_id
    where coalesce(
      c.total_commits,
      0
   ) > 0
       or coalesce(
      pr.prs_merged,
      0
   ) > 0
       or coalesce(
      i.issues_created,
      0
   ) > 0
    order by contribution_score desc;

-- =========================
-- VIEW 5: Repository Health Metrics
-- =========================
-- Purpose: Health and quality indicators for repositories
-- Replaces: fn_CalculateRepositoryHealth() function
-- Returns: Health score and metrics for each repository

create view vw_repositoryhealth as
   select r.repo_id,
          r.name as repository_name,
          coalesce(
             u.username,
             o.name
          ) as owner_name,
    
    -- Health indicators
          coalesce(
             issues.open_issue_count,
             0
          ) as open_issues,
          coalesce(
             issues.total_issues,
             0
          ) as total_issues,
          coalesce(
             prs.open_pr_count,
             0
          ) as open_pull_requests,
          coalesce(
             prs.merged_pr_count,
             0
          ) as merged_pull_requests,
    
    -- Issue resolution rate
          case
             when coalesce(
                issues.total_issues,
                0
             ) = 0 then
                null
             else
                round(
                   (coalesce(
                      issues.closed_issues,
                      0
                   ) * 100.0) / issues.total_issues,
                   2
                )
          end as issue_resolution_rate_percent,
    
    -- PR merge rate
          case
             when coalesce(
                prs.total_prs,
                0
             ) = 0 then
                null
             else
                round(
                   (coalesce(
                      prs.merged_pr_count,
                      0
                   ) * 100.0) / prs.total_prs,
                   2
                )
          end as pr_merge_rate_percent,
    
    -- Activity freshness
          julianday('now') - julianday(coalesce(
             commits.last_commit,
             r.created_at
          )) as days_since_last_commit,
    
    -- Health score (0-100)
          cast(
             case
            -- Recently active (< 30 days) = +30 points
                when julianday('now') - julianday(coalesce(
                   commits.last_commit,
                   r.created_at
                )) < 30 then
                   30
                when julianday('now') - julianday(coalesce(
                   commits.last_commit,
                   r.created_at
                )) < 90 then
                   15
                else
                   0
             end
             +
        -- Good issue resolution rate = +30 points
             case
                when coalesce(
                   issues.total_issues,
                   0
                ) = 0                                 then
                   20
                when(coalesce(
                   issues.closed_issues,
                   0
                ) * 100.0 / issues.total_issues) > 80 then
                   30
                when(coalesce(
                   issues.closed_issues,
                   0
                ) * 100.0 / issues.total_issues) > 50 then
                   20
                else
                   10
             end
             +
        -- Good PR merge rate = +20 points
             case
                when coalesce(
                   prs.total_prs,
                   0
                ) = 0                           then
                   15
                when(coalesce(
                   prs.merged_pr_count,
                   0
                ) * 100.0 / prs.total_prs) > 70 then
                   20
                when(coalesce(
                   prs.merged_pr_count,
                   0
                ) * 100.0 / prs.total_prs) > 40 then
                   10
                else
                   5
             end
             +
        -- Has activity (commits/issues/PRs) = +20 points
             case
                when coalesce(
                   commits.commit_count,
                   0
                ) > 10 then
                   20
                when coalesce(
                   commits.commit_count,
                   0
                ) > 0  then
                   10
                else
                   0
             end
          as real) as health_score,
    
    -- Health status
          case
             when cast(
                case
                   when julianday('now') - julianday(coalesce(
                      commits.last_commit,
                      r.created_at
                   )) < 30 then
                      30
                   else
                      0
                end
                +
                case
                   when coalesce(
                      issues.total_issues,
                      0
                   ) = 0 then
                      20
                   else
                      10
                end
                +
                case
                   when coalesce(
                      prs.total_prs,
                      0
                   ) = 0 then
                      15
                   else
                      10
                end
                +
                case
                   when coalesce(
                      commits.commit_count,
                      0
                   ) > 10 then
                      20
                   else
                      0
                end
             as real) >= 70 then
                'Healthy'
             when cast(
                case
                   when julianday('now') - julianday(coalesce(
                      commits.last_commit,
                      r.created_at
                   )) < 30 then
                      30
                   else
                      0
                end
                +
                case
                   when coalesce(
                      issues.total_issues,
                      0
                   ) = 0 then
                      20
                   else
                      10
                end
                +
                case
                   when coalesce(
                      prs.total_prs,
                      0
                   ) = 0 then
                      15
                   else
                      10
                end
                +
                case
                   when coalesce(
                      commits.commit_count,
                      0
                   ) > 10 then
                      20
                   else
                      0
                end
             as real) >= 40 then
                'Moderate'
             else
                'Needs Attention'
          end as health_status
     from repository r
     left join user u
   on r.owner_user_id = u.user_id
     left join organization o
   on r.owner_org_id = o.org_id
     left join (
      select repo_id,
             count(*) as commit_count,
             max(committed_at) as last_commit
        from gitcommit
       group by repo_id
   ) commits
   on r.repo_id = commits.repo_id
     left join (
      select repo_id,
             count(*) as total_issues,
             sum(
                case
                   when status = 'open' then
                      1
                   else
                      0
                end
             ) as open_issue_count,
             sum(
                case
                   when status = 'closed' then
                      1
                   else
                      0
                end
             ) as closed_issues
        from issue
       group by repo_id
   ) issues
   on r.repo_id = issues.repo_id
     left join (
      select repo_id,
             count(*) as total_prs,
             sum(
                case
                   when status = 'open' then
                      1
                   else
                      0
                end
             ) as open_pr_count,
             sum(
                case
                   when status = 'merged' then
                      1
                   else
                      0
                end
             ) as merged_pr_count
        from pullrequest
       group by repo_id
   ) prs
   on r.repo_id = prs.repo_id;

-- =========================
-- VERIFICATION
-- =========================
select '✅ Database views created successfully!' as status;

-- Show all views
select name as view_name,
       case
          when name like '%Stats%' then
             'Statistics & Metrics'
          when name like '%Activity%' then
             'Activity Tracking'
          when name like '%Active%' then
             'Activity Filtering'
          when name like '%Contributors%' then
             'User Rankings'
          when name like '%Health%' then
             'Health Monitoring'
          else
             'Other'
       end as view_category
  from sqlite_master
 where type = 'view'
   and name like 'vw_%'
 order by view_category,
          name;