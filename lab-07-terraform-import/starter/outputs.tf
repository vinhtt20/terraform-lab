# =====================================================================
# Lab 07 — STARTER: outputs sau khi import xong.
#
# Khai báo 3 output sau khi bạn đã viết các resource block trong main.tf.
# =====================================================================

# TODO O1: output "container_id"  — value = docker_container.legacy_app.id
# TODO O2: output "volume_name"   — value = docker_volume.legacy_data.name
# TODO O3: output "url"           — "http://localhost:<external_port>"
#          Hint: external port lấy qua tolist(docker_container.legacy_app.ports)[0].external
