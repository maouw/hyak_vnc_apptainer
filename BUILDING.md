# Building the containers on GitHub Actions

The containers are built using GitHub Actions. The workflow is defined in [`.github/workflows/apptainer-image.yml`](.github/workflows/apptainer-image.yml).

The workflow is triggered on every push with the tag `<containername>@*`. It builds the named container and pushes it to the GitHub Container Registry.

Before containers that depend on other containers can be built, the dependent containers must be built and pushed to the registry. So, if `hyakvnc-freesurfer-ubuntu22.04` depends on `hyakvnc-vncserver-ubuntu22.04`, you must first push a commit with the tag `hyakvnc-vncserver-ubuntu22.04@1.2345` for it to be built. Then, you can push a commit with the tag `hyakvnc-freesurfer-ubuntu22.04@1.2345`.

The way to do this is:

```bash
git tag -f hyakvnc-vncserver-ubuntu22.04@1.2345 @ -f to overwrite the tag if it already exists
git push -f origin hyakvnc-vncserver-ubuntu22.04@1.2345 @ -f to overwrite the tag if it already exists
```

You can also use the `bin/tag-release.sh` script to do this.
