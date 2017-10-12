# HBS OK VVV Provisioner

Provisioner for [VVV](https://github.com/Varying-Vagrant-Vagrants/VVV) that will set up a local environment for https://ok.hbs.org.

## Requirements

* [VVV](https://github.com/Varying-Vagrant-Vagrants/VVV) 2.0+: And its dependencies.
* [Customfile](https://gist.github.com/jjeaton/27863f56e3fbf02e8251090d50446859): See step 1 below.
* Your SSH key added in GitHub (it will be shared with the VM to automate repo configuration)

## Instructions

1. Install the [`Customfile`](https://gist.github.com/jjeaton/27863f56e3fbf02e8251090d50446859) to your VVV install, which will enable sharing of `known_hosts` between your host and guest vm. This is required to allow the use of a private repo as a provisioner. Once you have it, you will not need to repeat this step for any other VVV provisioners that are in private repos, as long as they are hosted on github. **NOTE**: If you already have a `Customfile`, you'll want to [view the gist](https://gist.github.com/jjeaton/27863f56e3fbf02e8251090d50446859) and merge it into your existing file.

    ```bash
    cd ${PATH_TO_VVV}
    curl -o Customfile https://gist.githubusercontent.com/jjeaton/27863f56e3fbf02e8251090d50446859/raw
    ```

1. Bring vagrant up

    ```bash
    vagrant up
    ```

1. Add the following to your `${PATH_TO_VVV}/vvv-custom.yml`:

    ```yaml
    hbsok:
      repo: git@github.com:reaktivstudios/vvv-hbsok.git
      hosts:
        - ok.hbs.dev
        - rctom.hbs.dev
        - digit.hbs.dev
        - fd2015.hbs.dev
    ```

1. Run this command from your `vvv` directory to provision just this site:

    ```bash
    vagrant provision --provision-with site-vip
    ```
