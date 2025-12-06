# MapDB GS4 Backup
This repository houses an up to date mirror of the official Lich mapdb and map images.

A github action is scheduled to run every 3 hours, check for any mapdb updates within that window and download them.

The changes are then committed back into the repo and pushed to the main branch.

On a commit action the repo is packaged using the [jinxp](https://github.com/elanthia-online/jinxp) tool (courtesy of [Ondreian](https://github.com/ondreian) and the [Elanthia Online](https://github.com/elanthia-online/) folks) and deployed via [GitHub Pages](https://github.com/) for use as a Jinx repo with Lich. Most of this repository was created with the tooling developed by FFNG for the [Lich Repo Mirror](https://github.com/FarFigNewGut/lich_repo_mirror).

You can add this mapdb backup repo by issuing:

```ruby
;jinx repo add mapdb-backup-gs https://elanthia-online.github.io/mapdb-backup-gs/
```

Once it is setup as a source for ;jinx you can update the mapdb from the repo with:

```ruby
# update mapdb
;jinx update mapdb.json --repo=mapdb-backup-gs
```
