// Copyright (c) 2011 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "include/cef_command_line.h"
#include "testing/gtest/include/gtest/gtest.h"

namespace {

void VerifyCommandLine(CefRefPtr<CefCommandLine> command_line) {
  std::string program = command_line->GetProgram();
  EXPECT_EQ("test.exe", program);

  EXPECT_TRUE(command_line->HasSwitches());

  EXPECT_TRUE(command_line->HasSwitch("switch1"));
  std::string switch1 = command_line->GetSwitchValue("switch1");
  EXPECT_EQ("", switch1);
  EXPECT_TRUE(command_line->HasSwitch("switch2"));
  std::string switch2 = command_line->GetSwitchValue("switch2");
  EXPECT_EQ("val2", switch2);
  EXPECT_TRUE(command_line->HasSwitch("switch3"));
  std::string switch3 = command_line->GetSwitchValue("switch3");
  EXPECT_EQ("val3", switch3);
  EXPECT_TRUE(command_line->HasSwitch("switch4"));
  std::string switch4 = command_line->GetSwitchValue("switch4");
  EXPECT_EQ("val 4", switch4);
  EXPECT_FALSE(command_line->HasSwitch("switchnoexist"));

  CefCommandLine::SwitchMap switches;
  command_line->GetSwitches(switches);
  EXPECT_EQ((size_t)4, switches.size());

  bool has1 = false, has2 = false, has3 = false, has4 = false;

  CefCommandLine::SwitchMap::const_iterator it = switches.begin();
  for (; it != switches.end(); ++it) {
    std::string name = it->first;
    std::string val = it->second;

    if (name == "switch1") {
      has1 = true;
      EXPECT_EQ("", val);
    } else if (name == "switch2") {
      has2 = true;
      EXPECT_EQ("val2", val);
    } else if (name == "switch3") {
      has3 = true;
      EXPECT_EQ("val3", val);
    } else if (name == "switch4") {
      has4 = true;
      EXPECT_EQ("val 4", val);
    }
  }

  EXPECT_TRUE(has1);
  EXPECT_TRUE(has2);
  EXPECT_TRUE(has3);
  EXPECT_TRUE(has4);

  EXPECT_TRUE(command_line->HasArguments());

  CefCommandLine::ArgumentList args;
  command_line->GetArguments(args);
  EXPECT_EQ((size_t)2, args.size());
  std::string arg0 = args[0];
  EXPECT_EQ("arg1", arg0);
  std::string arg1 = args[1];
  EXPECT_EQ("arg 2", arg1);

  command_line->Reset();
  EXPECT_FALSE(command_line->HasSwitches());
  EXPECT_FALSE(command_line->HasArguments());
  std::string cur_program = command_line->GetProgram();
  EXPECT_EQ(program, cur_program);
}

}  // namespace

// Test creating a command line from argc/argv or string.
TEST(CommandLineTest, Init) {
  CefRefPtr<CefCommandLine> command_line = CefCommandLine::CreateCommandLine();
  EXPECT_TRUE(command_line.get() != NULL);

#if defined(OS_WIN)
  command_line->InitFromString("test.exe --switch1 -switch2=val2 /switch3=val3 "
                               "-switch4=\"val 4\" arg1 \"arg 2\"");
#else
  const char* args[] = {
    "test.exe",
    "--switch1",
    "-switch2=val2",
    "-switch3=val3",
    "-switch4=val 4",
    "arg1",
    "arg 2"
  };
  command_line->InitFromArgv(sizeof(args) / sizeof(char*), args);
#endif

  VerifyCommandLine(command_line);
}

// Test creating a command line using set and append methods.
TEST(CommandLineTest, Manual) {
  CefRefPtr<CefCommandLine> command_line = CefCommandLine::CreateCommandLine();
  EXPECT_TRUE(command_line.get() != NULL);

  command_line->SetProgram("test.exe");
  command_line->AppendSwitch("switch1");
  command_line->AppendSwitchWithValue("switch2", "val2");
  command_line->AppendSwitchWithValue("switch3", "val3");
  command_line->AppendSwitchWithValue("switch4", "val 4");
  command_line->AppendArgument("arg1");
  command_line->AppendArgument("arg 2");

  VerifyCommandLine(command_line);
}
