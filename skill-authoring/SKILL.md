---
name: skill-authoring
description: Use when writing, importing, porting, or repairing a SKILL.md. Covers the frontmatter contract, importing a skill from another repo or another agent harness, and how skills share state and delegate to each other. Triggers on "write a skill", "add this skill", "port this skill", "the skill isn't firing", or a skill that loads with a wrong description.
---

# Skill authoring

## The frontmatter contract

```
---
name: <matches the directory name exactly>
description: <when to use it, in the words that appear in a real request>
---
```

The description is the whole trigger. A model picks a skill by reading it and nothing else, so it names situations and phrases, not the skill's philosophy. Add `disable-model-invocation: true` only for skills that should run when asked by name and never on the model's own initiative.

Broken frontmatter fails silently: the skill still lists, with the raw first line showing where the description belongs. A description that reads like file content means the fence did not parse.

## Importing a skill

Record where it came from in `<skill>/.source.txt`, one URL per line. That file is what makes the next repair cheap.

Text pasted out of a rendered chat arrives with every markdown character backslash-escaped, a blank line inserted between every line, and CRLF endings. Frontmatter never parses. Do not hand-repair it: re-fetch the canonical raw file from the upstream in `.source.txt` and overwrite. Enumerate what an upstream ships with the host's tree API before fetching, so reference files under the skill directory come along with `SKILL.md`. A missing reference file is the usual reason an imported skill half works.

Keep `* text=auto eol=lf` in the repo's `.gitattributes` so a re-paste cannot reintroduce CRLF.

## Porting from another harness

A skill written for a different agent harness names tools that do not exist here. It loads, reads plausibly, and quietly does nothing. Translate before trusting it:

- Subagent spawning: the foreign harness's tool name becomes `Agent`, with `subagent_type` from this harness's registry.
- Model identifiers: foreign slugs become the model names this harness accepts, or get omitted to inherit the session model.
- Transcript, config, and plugin paths: rewrite to the ones this harness uses, and verify one by listing it.
- Sibling skills the import references: confirm each one is installed. Strip or re-point the references that are not, rather than leaving a pointer to a skill nobody has.

## Skills that work together

Cross-skill state belongs in an artifact both skills can re-derive from the environment: a branch name, a path, a file, a commit trailer. Conversation context does not survive compaction, and a skill that depends on remembering an earlier turn fails on the session where it matters.

Before declaring a capability uncovered, list what the skill and plugin directories actually ship. Config files and READMEs overstate coverage. When an existing skill owns a capability, call it by name and let it own the mechanics. Copying its commands into your skill duplicates details that drift, and the copy is the one that goes stale.
