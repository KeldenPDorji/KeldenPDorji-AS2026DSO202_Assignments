# DSO202 - Assignment 4: GitOps with Argo CD

The GitOps repository is submitted separately, because Argo CD needs the brief's
own public repository to watch:

**[KeldenPDorji/dso202-gitops](https://github.com/KeldenPDorji/dso202-gitops)**

| Document | Contents |
|---|---|
| [`README.md`](https://github.com/KeldenPDorji/dso202-gitops/blob/main/README.md) | Versions, build sequence, cleanup, credential handling, deviations, Q1 to Q6 |
| [`docs/evidence.md`](https://github.com/KeldenPDorji/dso202-gitops/blob/main/docs/evidence.md) | Command output and the 22 screenshots, task by task |

This folder keeps only the scripts in [`verify/`](verify/) that produced that
evidence. They run from the root of a `dso202-gitops` clone. `t8b-finish.sh`
records the final state of drill 4 after `t8b.sh` timed out on its own wait.
