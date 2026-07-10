# Forge reference — default conventions

Defaults for repos **without** their own tracker doc. A repo's
`docs/agents/issue-tracker.md` overrides everything here. When bootstrapping a
new project's board, establish these (label creation is idempotent — 409 on
re-create is fine).

## Label vocabulary

Triage labels — every triaged issue gets exactly one category + one state:

| Label             | Kind     | Meaning                                  | Color     |
| ----------------- | -------- | ---------------------------------------- | --------- |
| `bug`             | category | something is broken                      | `#d9534f` |
| `enhancement`     | category | new feature / improvement                | `#5bc0de` |
| `needs-triage`    | state    | maintainer must evaluate                 | `#f0ad4e` |
| `needs-info`      | state    | waiting on reporter                      | `#f7e463` |
| `ready-for-agent` | state    | fully specified, AFK-agent-grabbable     | `#5cb85c` |
| `ready-for-human` | state    | needs a human                            | `#337ab7` |
| `wontfix`         | state    | will not be actioned (closed)            | `#777777` |

Wayfinder labels: `wayfinder:map` `#6699cc`, `:research` `#33aa33`,
`:prototype` `#ff9900`, `:grilling` `#cc3399`, `:task` `#8e8e8e`.

Agent status labels (scoped — GitLab swaps same-scope labels automatically;
set via `glab-board grab|park|close`, which also removes the siblings
explicitly): `agent::working` `#1f883d`, `agent::researching` `#33aaff`,
`agent::parked` `#f0ad4e`.

`hitl` (`#cc0033`) — orthogonal to type: the ticket cannot proceed without the
human. One query is then the human's whole queue (`-l hitl`); agent-takeable
work is `--not -l hitl`. Mixed tickets carry it and mark steps `HITL:`/`AFK:`.

```bash
glab api -X POST "projects/$ENC/labels" -f name='wayfinder:map' -f color='#6699cc'
```

## Ticket body template

```markdown
### Question

<one-line framing of the decision/work>

**Today:** <current state, one line>
**Decide one:** / numbered steps — numbered lists + sub-bullets, never a
run-on paragraph. <mark steps `HITL:` / `AFK:` when mixed>

**Gates:** <what this ticket unblocks>
**Detail:** <file/handoff pointer>
```

## Blocking (GitLab native)

Direction matters. "#A must wait for #B" = record from A's side:

```bash
glab api -X POST "projects/$ENC/issues/<A>/links" \
  -f target_project_id=$PID -f target_issue_iid=<B> -f link_type=is_blocked_by
```

(`glab-board block A B` does exactly this.) An item's `blocked` boolean counts
**open** blockers only — closing the last blocker flips it automatically;
that is the frontier engine.

## Wayfinder operations (GitLab default)

On GitLab an Issue cannot parent another Issue, so child tickets are **Task**
work items parented to the map Issue. Tasks share the issue iid space, appear
in `/issues` REST (`issue_type: task`), and take labels/assignees/blocking
like issues.

```bash
# map = an Issue labelled wayfinder:map; capture its global work-item id:
MAP_WI=$(glab api graphql -f query="{project(fullPath:\"$PROJECT\"){workItems(iids:[\"$MAP_IID\"]){nodes{id}}}}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["data"]["project"]["workItems"]["nodes"][0]["id"])')

# child ticket = Task parented to the map (then label via issues REST):
glab api graphql -f query="
mutation { workItemCreate(input:{
  projectPath:\"$PROJECT\", title:\"<title>\",
  workItemTypeId:\"gid://gitlab/WorkItems::Type/5\",
  hierarchyWidget:{ parentId:\"$MAP_WI\" }
}){ workItem{ iid } errors } }"
glab api -X PUT "projects/$ENC/issues/<child-iid>" -f 'labels=wayfinder:grilling'
```

Create tickets first, wire blocking second (iids must exist). Resolve = post a
`## Resolution` comment, close, append a one-liner to the map's
"Decisions so far".

## Observation intake

Turning a raw notes file into issues: split into discrete observations →
dedupe against open issues **by concept** (`glab-board list`, `--search`) →
classify (category + state; default `needs-triage`, `ready-for-agent` only
when fully specified) → create → report a table (observation → iid/URL or
"duplicate of #N").

## Recording contract (agent-link)

Where the metadata lives and how it is discovered: per-worktree git config
(`agent.issue` / `agent.mr`), written by `agent-link issue|mr <url>` from the
worktree; `glab-board grab` and `glab-board mr` do it for you. Read side
(human hotkeys, `/mr`, `/issue`) resolves cwd → pane process tree → pane
pointer → newest recording among the repo's worktrees.
