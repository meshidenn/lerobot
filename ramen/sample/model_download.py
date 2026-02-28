from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='airoa-org/airoa-moma',
    repo_type='dataset',
    revision='main',
    local_dir='~/lerobot_datasets/airoa-moma',
    allow_patterns=['meta/**', 'data/**', 'videos/**'],
)
print('Done')