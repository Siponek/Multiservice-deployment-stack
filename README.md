# Virtualization and Cloud Computing

Exam project

- [Giorgio Rengucci 4483986](mailto:4483986@studenti.unige.it)
- [Milo Galli 4483986](mailto:4483986@studenti.unige.it)
- [Szymon Piotr Zinkowicz 5181814](mailto:5181814@studenti.unige.it)

## Facilities available

- `make run-ansible` runs the Ansible playbook
- `make run-ansible-lint` runs the Ansible playbook linter
- An example inside of `examples` of the integration between Nextcloud and Keycloak

## Setup and configuration

- update `ansible_host` in [inventory.yml](inventory.yml) to fit your VMs ip addresses
- create a `secrets.yml` file in project root (see [secrets.yml.example](secrets.yml.example))
- set your sudo password for the two VMs inside `secrets.yml` using the format:
  ```txt
  vm1_sudo_password: "<your vm1 sudo password>"
  vm2_sudo_password: "<your vm2 sudo password>"
  ```
