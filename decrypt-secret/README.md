# Secret passing between jobs

Two parts:

1. `.github/workflows/get-aws-secret.yml` – reusable workflow. Assumes an AWS role via OIDC, optionally resolves the secret ARN from an SSM parameter, fetches one secret from Secrets Manager, and returns it GPG-encrypted as the `encrypted_secret` output.
2. `decrypt-secret` – composite action. Decrypts that output and exports it as an env var for later steps in the same job.

Encryption is needed because plain secrets can't be passed as job outputs (the runner masks and drops them).

## Usage

```yaml
jobs:
  get-secret:
    permissions:
      id-token: write
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
          encrypted_secret: ${{ needs.get-secret.outputs.encrypted_secret }}
          passphrase: ${{ secrets.PASSPHRASE }}
          secret_name: ENVIRONMENT_MANAGEMENT
      - run: echo "using the secret for ${{ matrix.item }}"   # $ENVIRONMENT_MANAGEMENT is set
```

## Inputs (workflow)

- `secret_name` (required): env var name the value is exported as (pass the same name to `decrypt-secret`).
- `secret_arn_ssm_parameter`: SSM parameter holding the secret ARN.
- `secret_id`: secret name or ARN; overrides the SSM parameter. One of the two is required.

## IAM

The role needs `secretsmanager:GetSecretValue` on the secret, and `ssm:GetParameter` on the parameter if used (plus `kms:Decrypt` for a SecureString or a CMK-encrypted secret).

## Notes

- Secrets are not inherited through nested reusable workflows. Each caller in the chain must pass them (`secrets: inherit` or explicit `secrets:`), otherwise `AWS_ACCOUNT_NUMBER` resolves to empty and the role ARN is invalid. The calling job also needs `permissions: id-token: write`.
- The secret is fetched once; each matrix job only decrypts.
- Masking is multiline-safe.
- If the secret is needed as the matrix definition itself, decrypt in a job that outputs the non-sensitive matrix, since masked values can't be job outputs.
