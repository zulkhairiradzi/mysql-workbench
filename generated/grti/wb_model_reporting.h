/*
 * Copyright (c) 2011, 2017, Oracle and/or its affiliates. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#pragma once

class WbModelReportingInterfaceWrapper : public grt::ModuleWrapper {
protected:
  friend class grt::GRT;
  WbModelReportingInterfaceWrapper(grt::Module* module) : grt::ModuleWrapper(module) {
  }

public:
  static const char* static_get_name() {
    return "WbModelReportingInterface";
  }
  ssize_t getAvailableReportingTemplates(const grt::StringListRef& param0) {
    grt::BaseListRef args(grt::AnyType);
    args.ginsert(param0);
    grt::ValueRef ret = _module->call_function("getAvailableReportingTemplates", args);
    return *grt::IntegerRef::cast_from(ret);
  }
  std::string getTemplateDirFromName(const std::string& param0) {
    grt::BaseListRef args(grt::AnyType);
    args.ginsert(grt::StringRef(param0));
    grt::ValueRef ret = _module->call_function("getTemplateDirFromName", args);
    return (std::string)grt::StringRef::cast_from(ret);
  }
  workbench_model_reporting_TemplateInfoRef getReportingTemplateInfo(const std::string& param0) {
    grt::BaseListRef args(grt::AnyType);
    args.ginsert(grt::StringRef(param0));
    grt::ValueRef ret = _module->call_function("getReportingTemplateInfo", args);
    return workbench_model_reporting_TemplateInfoRef::cast_from(ret);
  }
  ssize_t generateReport(const workbench_physical_ModelRef& param0, const grt::DictRef& param1) {
    grt::BaseListRef args(grt::AnyType);
    args.ginsert(param0);
    args.ginsert(param1);
    grt::ValueRef ret = _module->call_function("generateReport", args);
    return *grt::IntegerRef::cast_from(ret);
  }
};

