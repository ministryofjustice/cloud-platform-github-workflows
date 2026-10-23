# Secret passing between jobs

Two parts:

1. `.github/workflows/get-aws-secret.yml` – reusable workflow. Assumes an AWS role via OIDC, optionally resolves the secret ARN from an SSM parameter, fetches the secret from Secrets Manager, and returns it GPG-encrypted as the `encrypted_secrets` output.
2. `decrypt-secret` – composite action. Decrypts that output and exports each entry as an env var for later steps in the same job.

Encryption is needed because plain secrets can't be passed as job outputs (the runner masks and drops them).

## Usage

```yaml
jobs:
  get-secret:
    uses: ministryofjustice/cloud-platform-github-workflows/.github/workflows/get-aws-secret.yml@main
    with:
      secret_name: ENVIRONMENT_MANAGEMENT
      secret_arn_ssm_parameter: /my/app/secret-arn   # or secret_id: <name or ARN>
    secrets:
      AWS_ACCOUNT_NUMBER: ${{ secrets.AWS_ACCOUNT_NUMBER }}
      AWS_ROLE_NAME: ${{ secrets.AWS_ROLE_NAME }}
      PASSPHRASE: ${{ secrets.PASSPHRASE }}

  fan-out:
    needs: get-secret
    runs-on: ubuntu-latest
    strategy:
      matrix:
        item: [a, b, c]
    steps:
      - uses: ministryofjustice/cloud-platform-github-workflows/decrypt-secret@main
        with:
          encrypted_secrets: ${{ needs.get-secret.outputs.encrypted_secrets }}
          passphrase: ${{ secrets.PASSPHRASE }}
      - run: echo "using the secret for ${{ matrix.item }}"   # $ENVIRONMENT_MANAGEMENT is set
```

## Inputs (workflow)

- `secret_name` (required): env var name the value is exported as.
- `secret_arn_ssm_parameter`: SSM parameter holding the secret ARN.
- `secret_id`: secret name or ARN; overrides the SSM parameter. One of the two is required.
- `aws_region`: default `eu-west-2`.

## IAM

The role needs `secretsmanager:GetSecretValue` on the secret, and `ssm:GetParameter` on the parameter if used (plus `kms:Decrypt` for a SecureString or a CMK-encrypted secret).

## Notes

- The secret is fetched once; each matrix job only decrypts.
- The output is a JSON map (`{"NAME": "value"}`) so more secrets can be added later without changing the output name or the decrypt action.
- Masking is multiline-safe and also masks JSON string values.
- If the secret is needed as the matrix definition itself, decrypt in a job that outputs the non-sensitive matrix, since masked values can't be job outputs.
