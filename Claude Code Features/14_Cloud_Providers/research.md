# Cloud Providers (AWS Bedrock and Google Vertex AI)

## Overview

Claude Code can be configured to use Claude models through third-party cloud providers instead of the direct Anthropic API. The two primary cloud integrations are Amazon Bedrock and Google Vertex AI. Each provider has its own authentication methods, environment variables, model ID formats, and configuration requirements. When using cloud providers, the `/login` and `/logout` commands are disabled since authentication is handled through the provider's credential system.

## Key Capabilities

- **AWS Bedrock integration**: Use Claude models through Amazon Bedrock with IAM-based authentication
- **Google Vertex AI integration**: Use Claude models through Google Cloud's Vertex AI platform
- **Standard credential chains**: Both providers use their respective platform's default credential mechanisms
- **Cross-region inference**: Bedrock supports inference profile IDs for cross-region access
- **Global and regional endpoints**: Vertex AI supports both global and regional endpoints
- **Model version pinning**: Pin specific model versions to prevent breakage when new models are released
- **Automatic credential refresh**: Bedrock supports auto-refresh for SSO and corporate identity providers
- **AWS Guardrails**: Bedrock supports content filtering via Guardrails integration
- **Prompt caching**: Supported on both providers (may vary by region)
- **1M token context**: Vertex AI supports the 1M token context window for eligible models

---

## AWS Bedrock

### Prerequisites

- An AWS account with Bedrock access enabled
- Access to desired Claude models (e.g., Claude Sonnet 4.6) in Bedrock
- AWS CLI installed and configured (optional, if using another credential mechanism)
- Appropriate IAM permissions

### Configuration / Setup

#### Step 1: Submit use case details

First-time users must submit use case details via the Amazon Bedrock console:
1. Navigate to the [Amazon Bedrock console](https://console.aws.amazon.com/bedrock/)
2. Select "Chat/Text playground"
3. Choose any Anthropic model and fill out the use case form

#### Step 2: Configure AWS credentials

Claude Code uses the default AWS SDK credential chain. Options:

**Option A: AWS CLI configuration**
```bash
aws configure
```

**Option B: Environment variables (access key)**
```bash
export AWS_ACCESS_KEY_ID=your-access-key-id
export AWS_SECRET_ACCESS_KEY=your-secret-access-key
export AWS_SESSION_TOKEN=your-session-token
```

**Option C: SSO profile**
```bash
aws sso login --profile=<your-profile-name>
export AWS_PROFILE=your-profile-name
```

**Option D: AWS Management Console credentials**
```bash
aws login
```

**Option E: Bedrock API keys**
```bash
export AWS_BEARER_TOKEN_BEDROCK=your-bedrock-api-key
```

Bedrock API keys provide a simpler authentication method without needing full AWS credentials.

#### Step 3: Enable Bedrock in Claude Code

```bash
# Required: Enable Bedrock integration
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-east-1  # Required; does not read from .aws config

# Optional: Override region for the small/fast model (Haiku)
export ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION=us-west-2
```

#### Step 4: Pin model versions

Pin specific model versions to prevent breakage when Anthropic releases new models:

```bash
export ANTHROPIC_DEFAULT_OPUS_MODEL='us.anthropic.claude-opus-4-6-v1'
export ANTHROPIC_DEFAULT_SONNET_MODEL='us.anthropic.claude-sonnet-4-6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'
```

These use cross-region inference profile IDs (with `us.` prefix). Adjust for different region prefixes or application inference profiles.

**Default models (when no pinning is set):**

| Model type | Default value |
|-----------|---------------|
| Primary model | `global.anthropic.claude-sonnet-4-6` |
| Small/fast model | `us.anthropic.claude-haiku-4-5-20251001-v1:0` |

**Custom model configuration:**
```bash
# Using inference profile ID
export ANTHROPIC_MODEL='global.anthropic.claude-sonnet-4-6'
export ANTHROPIC_SMALL_FAST_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'

# Using application inference profile ARN
export ANTHROPIC_MODEL='arn:aws:bedrock:us-east-2:your-account-id:application-inference-profile/your-model-id'

# Optional: Disable prompt caching if needed
export DISABLE_PROMPT_CACHING=1
```

### Advanced credential configuration

For automatic credential refresh (SSO and corporate identity providers), add to your Claude Code settings file:

```json
{
  "awsAuthRefresh": "aws sso login --profile myprofile",
  "env": {
    "AWS_PROFILE": "myprofile"
  }
}
```

- **`awsAuthRefresh`**: For commands that modify the `.aws` directory (SSO cache, credentials). The command's output is displayed but interactive input is not supported.
- **`awsCredentialExport`**: For directly returning credentials when you cannot modify `.aws`. Must output JSON:

```json
{
  "Credentials": {
    "AccessKeyId": "value",
    "SecretAccessKey": "value",
    "SessionToken": "value"
  }
}
```

### IAM permissions

Required IAM policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowModelAndInferenceProfileAccess",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ListInferenceProfiles"
      ],
      "Resource": [
        "arn:aws:bedrock:*:*:inference-profile/*",
        "arn:aws:bedrock:*:*:application-inference-profile/*",
        "arn:aws:bedrock:*:*:foundation-model/*"
      ]
    },
    {
      "Sid": "AllowMarketplaceSubscription",
      "Effect": "Allow",
      "Action": [
        "aws-marketplace:ViewSubscriptions",
        "aws-marketplace:Subscribe"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:CalledViaLast": "bedrock.amazonaws.com"
        }
      }
    }
  ]
}
```

### AWS Guardrails

Configure content filtering via Bedrock Guardrails in your settings file:

```json
{
  "env": {
    "ANTHROPIC_CUSTOM_HEADERS": "X-Amzn-Bedrock-GuardrailIdentifier: your-guardrail-id\nX-Amzn-Bedrock-GuardrailVersion: 1"
  }
}
```

### Bedrock troubleshooting

- **Region issues**: Check model availability with `aws bedrock list-inference-profiles --region your-region`
- **"On-demand throughput isn't supported"**: Specify the model as an inference profile ID
- Claude Code uses the Bedrock Invoke API and does **not** support the Converse API

---

## Google Vertex AI

### Prerequisites

- A Google Cloud Platform (GCP) account with billing enabled
- A GCP project with Vertex AI API enabled
- Access to desired Claude models (e.g., Claude Sonnet 4.6)
- Google Cloud SDK (`gcloud`) installed and configured
- Quota allocated in the desired GCP region

### Configuration / Setup

#### Step 1: Enable Vertex AI API

```bash
gcloud config set project YOUR-PROJECT-ID
gcloud services enable aiplatform.googleapis.com
```

#### Step 2: Request model access

1. Navigate to the [Vertex AI Model Garden](https://console.cloud.google.com/vertex-ai/model-garden)
2. Search for "Claude" models
3. Request access to desired Claude models
4. Wait for approval (may take 24-48 hours)

#### Step 3: Configure GCP credentials

Claude Code uses standard Google Cloud authentication. When authenticating, Claude Code automatically uses the project ID from `ANTHROPIC_VERTEX_PROJECT_ID`. To override, set `GCLOUD_PROJECT`, `GOOGLE_CLOUD_PROJECT`, or `GOOGLE_APPLICATION_CREDENTIALS`.

#### Step 4: Enable Vertex AI in Claude Code

```bash
# Required: Enable Vertex AI integration
export CLAUDE_CODE_USE_VERTEX=1
export CLOUD_ML_REGION=global
export ANTHROPIC_VERTEX_PROJECT_ID=YOUR-PROJECT-ID

# Optional: Disable prompt caching if needed
export DISABLE_PROMPT_CACHING=1

# When CLOUD_ML_REGION=global, override region for unsupported models
export VERTEX_REGION_CLAUDE_3_5_HAIKU=us-east5
```

**Optional per-model region overrides:**
```bash
export VERTEX_REGION_CLAUDE_3_5_SONNET=us-east5
export VERTEX_REGION_CLAUDE_3_7_SONNET=us-east5
export VERTEX_REGION_CLAUDE_4_0_OPUS=europe-west1
export VERTEX_REGION_CLAUDE_4_0_SONNET=us-east5
export VERTEX_REGION_CLAUDE_4_1_OPUS=europe-west1
```

#### Step 5: Pin model versions

```bash
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-6'
export ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-4-6'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='claude-haiku-4-5@20251001'
```

**Default models (when no pinning is set):**

| Model type | Default value |
|-----------|---------------|
| Primary model | `claude-sonnet-4-6` |
| Small/fast model | `claude-haiku-4-5@20251001` |

### IAM permissions

The `roles/aiplatform.user` role includes the required permission:
- `aiplatform.endpoints.predict` -- required for model invocation and token counting

For more restrictive permissions, create a custom role with only the permissions above.

### 1M token context window

Claude Sonnet 4 and Sonnet 4.6 support the 1M token context window on Vertex AI. This feature is currently in beta and requires the `context-1m-2025-08-07` beta header.

### Vertex AI troubleshooting

- **Quota issues**: Check or request quota increase through Cloud Console
- **"Model not found" 404 errors**: Confirm model is enabled in Model Garden; verify region access
- **Global endpoint issues**: Check that your models support global endpoints in Model Garden. For unsupported models, use `VERTEX_REGION_<MODEL_NAME>` overrides
- **429 errors**: Ensure primary and small/fast models are supported in your region; consider switching to `CLOUD_ML_REGION=global`

---

## Important Details

### Common to both providers

- **`/login` and `/logout` are disabled** when using Bedrock or Vertex AI, since authentication is handled through the cloud provider's credentials
- **Pin model versions for every deployment**: Without pinning, Claude Code uses model aliases that resolve to the latest version. New model releases can break users whose accounts do not have the new version enabled.
- **Prompt caching**: Automatically supported on both providers but may not be available in all regions. Disable with `DISABLE_PROMPT_CACHING=1`.
- **Cost tracking on cloud providers**: Claude Code does not send metrics from your cloud. For cost metrics, enterprises report using LiteLLM (open-source, unaffiliated with Anthropic) to track spend by key.
- **Dedicated accounts recommended**: Create a dedicated AWS account or GCP project for Claude Code to simplify cost tracking and access control.
- **Settings files for sensitive env vars**: Use settings files for environment variables like `AWS_PROFILE` that you do not want to leak to other processes.

### Environment variable summary

| Variable | Provider | Purpose |
|----------|----------|---------|
| `CLAUDE_CODE_USE_BEDROCK` | Bedrock | Enable Bedrock integration (set to `1`) |
| `AWS_REGION` | Bedrock | Required; specify AWS region |
| `CLAUDE_CODE_USE_VERTEX` | Vertex AI | Enable Vertex AI integration (set to `1`) |
| `CLOUD_ML_REGION` | Vertex AI | Set to `global` or a specific region |
| `ANTHROPIC_VERTEX_PROJECT_ID` | Vertex AI | Your GCP project ID |
| `ANTHROPIC_MODEL` | Both | Override the primary model |
| `ANTHROPIC_SMALL_FAST_MODEL` | Both | Override the small/fast model |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Both | Pin the Opus model version |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Both | Pin the Sonnet model version |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Both | Pin the Haiku model version |
| `DISABLE_PROMPT_CACHING` | Both | Disable prompt caching (set to `1`) |

## References

- [Claude Code on Amazon Bedrock](https://docs.anthropic.com/en/docs/claude-code/bedrock) -- Official Bedrock setup documentation
- [Claude Code on Google Vertex AI](https://docs.anthropic.com/en/docs/claude-code/vertex) -- Official Vertex AI setup documentation
- [Model Configuration](https://docs.anthropic.com/en/docs/claude-code/model-config) -- Model pinning and environment variables
- [Settings](https://docs.anthropic.com/en/docs/claude-code/settings) -- Settings file locations and configuration
- [Bedrock IAM Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/security-iam.html) -- AWS IAM details for Bedrock
- [Vertex AI IAM Documentation](https://cloud.google.com/vertex-ai/docs/general/access-control) -- GCP IAM details for Vertex AI
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/) -- AWS Bedrock pricing details
- [Vertex AI Pricing](https://cloud.google.com/vertex-ai/pricing) -- Google Vertex AI pricing details
