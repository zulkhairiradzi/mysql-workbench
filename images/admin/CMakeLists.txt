set(IMAGE_FILES
	../ui/options-horizontal-separator.png
	admin_add_user.png
	admin_audit_inspector.png
	admin_config_wizard.png
	admin_connections.png
	admin_dashboard.png
	admin_export.png
    admin_firewall.png
	admin_info_running.png
	admin_info_stopped.png
	admin_info_unknown.png
    admin_info_offline.png
	admin_instrumentation_setup.png
	admin_manage_exported.png
	admin_manage_privs.png
	admin_meb_backup.png
	admin_meb_restore.png
	admin_option_file.png
	admin_performance_reports.png
	admin_restore_data.png
	admin_schema_management.png
	admin_scripts.png
	admin_server_logs.png
	admin_server_status.png
	admin_start_stop.png
	admin_status_vars.png
	admin_system_startup.png
	dashboard_arrow_in_static.png
	dashboard_arrow_out_static.png
	dashboard_header_innodb_light.png
	dashboard_header_mysql_light.png
	dashboard_header_network_light.png
	dashboard_header_innodb_dark.png
	dashboard_header_mysql_dark.png
	dashboard_header_network_dark.png
	dashboard_separator.png
	mysql-logo-00.png
	mysql-logo-50.png
	mysql-logo-51.png
	mysql-logo-55.png
	mysql-logo-56.png
	mysql-logo-57.png
	mysql-logo-58.png
	mysql-status-off.png
	mysql-status-on.png
	mysql-status-separator-linux.png
	mysql-status-separator.png
	page_restore.png
	ps_easysetup_logo.png
	ps_easysetup_logo_enabled.png
	ps_overview.png
	ps_switcher_custom_hoover.png
	ps_switcher_custom_off.png
	ps_switcher_custom_on.png
	ps_switcher_default_hoover.png
	ps_switcher_default_off.png
	ps_switcher_default_on.png
	ps_switcher_disabled_hoover.png
	ps_switcher_disabled_off.png
	ps_switcher_disabled_on.png
	ps_switcher_fully_hoover.png
	ps_switcher_fully_off.png
	ps_switcher_fully_on.png
	ps_switcher_legend.png
	ps_switcher_text_light.png
	ps_switcher_text_dark.png
	title_backup.png
	title_connections.png
	title_dashboard.png
	title_export.png
	title_import.png
	title_instrumentation_setup.png
	title_logs.png
	title_options.png
	title_performance_reports.png
	title_restore.png
	title_startup.png
	title_users.png
	title_variables.png
	wb-backup-logo-small.png
	wb-backup-logo.png
	wb_perform_config.png
)

install(FILES ${IMAGE_FILES} DESTINATION ${WB_PACKAGE_SHARED_DIR}/images)
