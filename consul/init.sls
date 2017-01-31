{% from 'consul/map.jinja' import consul as consul %}
consul_packages:
  pkg.installed:
    - pkgs: {{consul['packages']}}
consul_user:
  user.present:
    - name: consul
    - shell: /bin/bash
    - home: {{consul['install_dir']}}
consul_scripts:
  file.recurse:
    - name: {{ consul['scripts_dir'] }}
    - source: salt://consul/scripts
    - dir_mode: '0755'
    - file_mode: '0755'
    - user: consul
    - group: consul
    - template: jinja
{% for datacenter, datacenter_opts in consul['datacenter'].iteritems() %}
consul_install-{{datacenter}}_dir:
  file.directory:
    - name: {{consul['install_dir']}}/{{datacenter}}/bin
    - makedirs: True
    - user: consul
    - group: consul
    - mode: 755
consul_install-{{datacenter}}:
  cmd.run:
    - name: {{ consul['scripts_dir'] }}/install_consul
    - env:
      - INSTALLDIR: {{consul['install_dir']}}/{{datacenter}}/bin
      {% if datacenter_opts['version'] is defined %}
      - VERSION: {{datacenter_opts['version']}}
      {% else %}
      - VERSION: latest
      {% endif %}
    - creates: {{consul['install_dir']}}/{{datacenter}}/bin/consul
consul_config-{{datacenter}}_dir:
  file.directory:
    - name: {{consul['install_dir']}}/{{datacenter}}/config
    - makedirs: True
    - user: consul
    - group: consul
    - mode: 0755
consul_config-{{datacenter}}:
  file.managed:
    - name: {{consul['install_dir']}}/{{datacenter}}/config/config.json
    - source: salt://consul/config/consul/config.json.tmpl
    - user: root
    - group: root
    - mode: 0644
    - template: jinja
    - context:
      datacenter_opts: {{ datacenter_opts['config'] }}
{% if consul['init'] =='systemd' %}
/etc/systemd/system/consul-{{datacenter}}.service:
  file.managed:
    - source: salt://consul/init/systemd/consul.service
    - mode: 0644
    - user: root
    - group: root
    - template: jinja
    - context:
      datacenter: {{datacenter}}
      install_dir: {{consul['install_dir']}}
{% if datacenter_opts['service']['enabled'] == True %}
consul-{{datacenter}}_service:
  service.running:
    - name: consul-{{datacenter}}
    - watch:
      - file: {{consul['install_dir']}}/{{datacenter}}/config/config.json
{% if datacenter_opts['service']['on_boot'] == True %}
    - enable: True
{% else %}
    - enable: False
{% endif %}
{% else %}
consul-{{datacenter}}_service-disableall:
  service.dead:
    - name: 'consul-*'
{% if datacenter_opts['service']['on_boot'] == True %}
    - enable: True
{% else %}
    - enable: False
{% endif %}
{% endif %}
{% endif %}
{% endfor %}
consul-service-dnsmasq:
  file.directory:
    - name: /etc/dnsmasq.d
    - user: root
    - group: root
    - mode: 0755
    - makedirs: True
  cmd.run:
    - name: service dnsmasq restart
    - watch:
      - file: consul-service-dnsmasq-mainconfig
      - file: consul-service-dnsmasq-consul
consul-service-dnsmasq-mainconfig:
  file.managed:
    - name: /etc/dnsmasq.conf
    - user: root
    - group: root
    - mode: 644
    - contents:
      - conf-dir=/etc/dnsmasq.d
consul-service-dnsmasq-consul:
  file.managed:
    - name: /etc/dnsmasq.d/tinc.conf
    - user: root
    - group: root
    - mode: 644
    - contents:
      - "server=8.8.8.8"
      - "server=8.8.4.4"
      - "server=/consul/127.0.0.1#8600"
{% if grains['virtual'] == "openvzve" %}
consul-service-dnsmasq-resolvconf-openvz_fix-open:
  cmd.run:
    - name: chattr -i /etc/resolv.conf
{% endif %}
consul-service-dnsmasq-resolvconf:
  file.managed:
    - name: /etc/resolv.conf
    - user: root
    - group: root
    - mode: 644
    - contents:
      - nameserver 127.0.0.1
{% if grains['virtual'] == "openvzve" %}
consul-service-dnsmasq-resolvconf-openvz_fix-close:
  cmd.run:
    - name: chattr +i /etc/resolv.conf
{% endif %}
