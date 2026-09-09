# STG環境でユーザーにエネルギーを手動付与する手順

sdd-cuckoo-workspace（fantopia）で、テスト目的でSTGの特定ユーザーにエネルギー（`energy_grants`/`energy_transactions`）を手動付与する手順。管理者向けの付与API・admin画面機能は存在しないため、DB直接操作で行う。

## 前提

- AWS CLIプロファイル `aic-cuck-aws`（STG用、SSO AdministratorAccess）が設定済み
- ローカルに `docker`, `session-manager-plugin` がインストール済み
- 対象ユーザーの `user_id`（UUID）が分かっている

## 1. 踏み台インスタンスの起動確認

```bash
aws ec2 describe-instances --profile aic-cuck-aws \
  --filters "Name=tag:Name,Values=fantopia-stg-bastion" \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name}'
```

`stopped` の場合は起動する（作業後は元の状態に戻す。他人が起動済みなら自分では停止しない）。

```bash
aws ec2 start-instances --profile aic-cuck-aws --instance-ids <instance-id>
```

## 2. Auroraエンドポイント確認

```bash
aws rds describe-db-clusters --profile aic-cuck-aws \
  --query 'DBClusters[?contains(DBClusterIdentifier,`stg`)].{Id:DBClusterIdentifier,Endpoint:Endpoint}'
```

## 3. SSMポートフォワード開始（バックグラウンド実行）

```bash
aws ssm start-session --profile aic-cuck-aws --target <bastion-instance-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="<Auroraエンドポイント>",portNumber="5432",localPortNumber="15433"
```

## 4. DB接続確認

`DATABASE_URL`はSSM Parameter Store `/fantopia/stg/app/secrets/database_url`（`fantopia_app`権限、アプリと同じ権限に留める）。値は画面に出力しない。ホスト部分を`host.docker.internal:15433`に置換し、Prisma固有のクエリパラメータ`uselibpqcompat`は`psql`が認識しないため除去する。

```bash
export DB_URL=$(aws ssm get-parameter --profile aic-cuck-aws \
  --name "/fantopia/stg/app/secrets/database_url" --with-decryption \
  --query 'Parameter.Value' --output text)
export DB_URL_LOCAL=$(echo "$DB_URL" | sed -E 's#@[^/]+/#@host.docker.internal:15433/#; s#[&?]uselibpqcompat=true##')
docker run --rm -e PGURL="$DB_URL_LOCAL" postgres:17 sh -c 'psql "$PGURL" -c "SELECT 1"'
```

## 5. 対象ユーザーの現在残高を確認

残高はキャッシュを持たず`energy_grants`の`remaining`合計（未失効分のみ）で計算する設計（`energy.service.ts`の`getBalance`と同じロジック）。

```sql
SELECT COALESCE(SUM(remaining),0) AS balance
FROM energy_grants
WHERE user_id = '<user_id>'
  AND remaining > 0
  AND (expires_at IS NULL OR expires_at > now());
```

## 6. 付与INSERT

`energy_grants`と`energy_transactions`をトランザクションでまとめて追加する。`balance_after`は手順5で確認した残高＋付与量。

```sql
BEGIN;
WITH new_grant AS (
  INSERT INTO energy_grants (id, user_id, amount, remaining, source, expires_at, transaction_key)
  VALUES (gen_random_uuid(), '<user_id>', <amount>, <amount>, 'login_bonus', <expires_at or NULL>,
          'login_bonus:manual:<user_id>:<YYYYMMDD>')
  RETURNING id
)
INSERT INTO energy_transactions (id, user_id, message_id, kind, amount, balance_after, transaction_key, reason, description, grant_id)
SELECT gen_random_uuid(), '<user_id>', NULL, 'grant', <amount>, <balance_after>,
       'login_bonus:manual:<user_id>:<YYYYMMDD>', 'login_bonus',
       'STGテスト用手動付与', id
FROM new_grant;
COMMIT;
```

### 注意点

- `energy_grants.source`はenum制約で`login_bonus`/`first_login_bonus`の2値のみ許可される。管理者による任意付与を表す値が存在しないため、`login_bonus`で代用し、`description`に手動付与である旨を記録して監査上の実態と一致させる。
- `transaction_key`は正規のログインボーナスclaim API（`login_bonus:{userId}:{日付}`）が使う冪等キーと衝突しないよう、`:manual:`を挟んだ値にする。衝突すると正規APIが「取得済み」と誤判定する。
- `users.last_login_bonus_date`/`login_bonus_streak`は更新しない。更新すると正規のclaim APIのストリーク計算に影響する。

## 7. 後片付け

- ポートフォワードのバックグラウンドプロセスを停止する
- 踏み台インスタンスは、自分が起動した場合のみ停止する（元から起動していた場合は他作業者への影響を避けそのままにする）

```bash
aws ec2 stop-instances --profile aic-cuck-aws --instance-ids <instance-id>
```

## 関連ファイル

- `sdd-cuckoo-backend/src/energy/energy.service.ts` — 残高集計・初回ログインボーナス付与ロジック
- `sdd-cuckoo-backend/src/energy/energy-login-bonus.service.ts` — 日次ログインボーナスclaimロジック
- `sdd-cuckoo-backend/prisma/schema.prisma`（`energy_grants`/`energy_transactions`定義、1174-1245行目付近）
- `sdd-cuckoo-infra/docs/new-environment-setup.md`（踏み台経由DB接続手順の原典）
