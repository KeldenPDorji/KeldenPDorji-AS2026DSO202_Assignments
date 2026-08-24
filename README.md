# DSO202 - Assignments

Coursework repository for **DSO202 - Scaling, Orchestration, Monitoring & Observability**.

| | |
|---|---|
| **Student** | Kelden P. Dorji |
| **Academic year** | AS2026 |
| **Assessment** | Four assignments, 10 marks each |

Each assignment lives in its own folder with a self-contained report, its manifests, and the
evidence behind every claim it makes.

| # | Topic | Unit | Status | Folder |
|---|---|---|---|---|
| 1 | Three-tier application deployment on a Kubernetes cluster | I | ✅ Complete | [`assignment-1/`](assignment-1/README.md) |
| 2 | - | - | Not yet released | - |
| 3 | - | - | Not yet released | - |
| 4 | - | - | Not yet released | - |

---

## Assignment 1 at a glance

A pre-built three-tier Task Tracker - nginx frontend → Node.js REST backend → PostgreSQL -
deployed to a local `kind` cluster entirely through declarative manifests. No application code
was written; the graded work is the Kubernetes configuration.

| | |
|---|---|
| **Namespace** | `dso202-assignment-01` |
| **Cluster** | `kind` cluster `dso202` from Practical 1 - 1 control-plane + 2 workers, Kubernetes v1.36.1 |
| **Frontend** | `sarojsanyasi/dso202-frontend:1.0` → `frontend-svc`, NodePort 30080 |
| **Backend** | `sarojsanyasi/dso202-backend:1.0` → `backend-svc`, ClusterIP |
| **Database** | `sarojsanyasi/dso202-db:1.0` → `db-svc`, headless (`clusterIP: None`), PVC-backed |

**What it covers:** namespace-scoped multi-tenancy, ConfigMap/Secret separation across two
conflicting environment-variable conventions, persistent storage through kind's default
provisioner, all three Service types, ResourceQuota and LimitRange governance, and a verified
CRUD / DNS / self-healing / declarative-vs-imperative evidence set. A read-only RBAC
Role and RoleBinding are included for the optional bonus.

**Start here:** [`assignment-1/README.md`](assignment-1/README.md) - the full report, including
the architecture note, the quota justification, the Secret encoding caveat, and the ten
screenshots of evidence.

```
assignment-1/
├── README.md          the report
├── *.yaml             namespace, ConfigMap, Secret, quota, RBAC
├── cluster/           kind cluster config (defines the 30080 port mapping)
├── database/          PVC, Deployment, headless Service
├── backend/           Deployment, ClusterIP Service
├── frontend/          Deployment, NodePort Service
├── verify/            the scripts that produced the evidence
└── evidence/          screenshots 01-10
```

---

## Conventions

- Manifests are split by tier and applied declaratively with `kubectl apply -f`.
- Image tags are pinned to a released version; `latest` is never used.
- Credentials live only in a `Secret` - never in a ConfigMap, Deployment, or Service.
- Every claim in a report is backed by a screenshot in that assignment's `evidence/` folder.
