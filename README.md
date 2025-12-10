# Kubeflow Ingest

**Enterprise Data Ingestion for Kubeflow Pipelines**

Connect SharePoint, Confluence, and enterprise data sources to Kubeflow Pipelines using declarative YAML. No custom code required.

**[View Documentation](https://aronchick.github.io/kubeflow-ingest/kubeflow/)**

---

## The Problem

Your enterprise customers have data locked in SharePoint, Confluence, S3, and Google Drive. They want to build RAG applications with Kubeflow Pipelines and Llamastack. But there's a missing piece:

```
SharePoint → ??? → PVC → Kubeflow Pipeline → Llamastack
```

Someone has to build the connector. The polling logic. The OAuth flow. The document transformation. The retry logic.

## The Solution

**Expanso** fills the gap. Poll enterprise sources, transform documents with Dockling, land on PVC, trigger Kubeflow Pipelines. All in ~30 lines of YAML.

```
SharePoint → Expanso → Dockling → PVC → Kubeflow Pipeline → Llamastack
```

## Architecture

| Component | Role |
|-----------|------|
| **Expanso** | Data pipeline orchestrator (200+ connectors) |
| **Dockling** | Document transformation (PDF, DOCX → text) |
| **PVC** | Kubernetes persistent storage |
| **Kubeflow Pipelines** | ML workflow orchestration |

## Pipeline Examples

### SharePoint Ingestion

```yaml
input:
  http_client:
    url: "https://graph.microsoft.com/v1.0/sites/${SITE_ID}/drive/root/children"
    verb: GET
    headers:
      Authorization: "Bearer ${SHAREPOINT_TOKEN}"

pipeline:
  processors:
    # Route PDF/DOCX through Dockling
    - switch:
      - check: this.name.has_suffix(".pdf")
        processors:
          - subprocess:
              name: dockling
              args: ["extract", "--format", "markdown"]

output:
  file:
    path: /mnt/pvc/incoming/${! this.id }.json
```

### Trigger KFP on New Documents

```yaml
input:
  file:
    paths: ["/mnt/pvc/incoming/*.json"]

output:
  http_client:
    url: "${KFP_API_URL}/apis/v2beta1/runs"
    verb: POST
```

## Quick Start

```bash
# Clone the repository
git clone https://github.com/aronchick/kubeflow-ingest.git
cd kubeflow-ingest

# View pipeline examples
ls kubeflow/pipelines/
```

## Repository Structure

```
kubeflow/
├── index.html                         # Documentation site
└── pipelines/
    ├── expanso-sharepoint-ingest.yaml # SharePoint → PVC
    ├── expanso-confluence-ingest.yaml # Confluence → PVC
    └── expanso-kfp-trigger.yaml       # PVC → KFP trigger
```

## Key Benefits

- **200+ Connectors**: SharePoint, Confluence, S3, GCS, Kafka, PostgreSQL, and more
- **Zero Custom Code**: Declarative YAML pipelines
- **Built-in Resilience**: Automatic retries, error handling, observability
- **OpenShift Ready**: Runs as a pod, writes to PVC, integrates with existing infrastructure

## Learn More

- [Expanso Documentation](https://docs.expanso.io)
- [Redpanda Connect](https://docs.redpanda.com/redpanda-connect)
- [Kubeflow Pipelines](https://kubeflow.org)

## License

Apache 2.0
