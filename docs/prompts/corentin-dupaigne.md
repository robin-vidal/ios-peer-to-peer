# Prompt journal, corentin-dupaigne

Prompts as sent, in the language they were written in, chronological order.
Method and rules are in [README.md](README.md).

---

1. I'm working on the dev secops part of an IOs school project. I have multiple ideas. Firstly pipelines with security check, dependency check, on each push a report is made by sonarcube or an alternative that will check for potential risk injections. I'm also thinking of adding a blackbox emulator feature for the redteam that will basically run the app in an emulator so the redteam can try to finding securities vulnerabilites from a user/backbox environment. Do you have recommendations on other features I could do for this project and do you think my ideas are decent

2. What is the difference between sonarqub and semgrep. What is OWASP MASVS and which ressource do you recommend me to read to understand OWASP MASVS and overall what I need to understand for this mission.

3. Ok so OWASP MASVS is concretly a convention of security domains for mobile applications. Is it right? But how do I concretly include the owasp masvs into my workflow

4. So I need a tool for each category of the owasp masvs standard? I guess some tool does multiple part of the standard ?

5. So the convention is to documentate a coverage matrix explaining every tool needed for each category of the masvs standard? So that should be the first step before building the pipelines?

6. So sometimes some categories of masvs are not important for some apps ? There is no way to make an app agnostic devsecops system?

7. What is this?

   ```yaml
   # security.yml (in each app repo)
   masvs_profile: L1
   fail_on: [critical, high]
   custom_rules: ./semgrep-rules/
   redteam_env: true
   ```

   Also what is mobsf

8. OK. So what are the first few github issues to make

9. Where is the owasp mask checklist

10. [Pasted: the mas.owasp.org news page "MASTG v2.0.0 Removes MAS Checklists"]

11. Can you make me the matrix template

12. WHat is a mas testing profile

13. You recommend me to use profiles ?

14. Ok, so then this matrix will the base on what the dev secops pipeline and architecture will be built on >?

15. And what should the context doc contain

16. Yeah make me the markdown template

17. Ok give me the github issues for the security context and coverage matrice. Here is an issue example for this repo :
    [Attached: issue #36 "feat(client): peer frame codec and pinned tls sessions" and the project board]

18. So the actual masvs issue is good enough or do I need to update it? ANd the context issue is still needed ?

19. [Attached: issue #45 "docs: masvs audit grid, all eight domains" and the project board]

20. SO I do not need to add any issue?

21. What is a stride dossier

22. Is it decent ?
    [Attached: issue #44 "docs: stride dossier over the whole system" and the project board]

23. Ok so the firsts dev secops issues are already there, no need to add any for now? Also does the matrix template you gave me correspond to the issue? And do I still need to build the security context?

24. Ok so what do I need to start with and and which doc files do I create. Do I need new tempaltes?

25. So masvs is a complete audit. Is it the equivalent of the matrix we wanted? Does an audit makes sense even in an early developpement stage?

26. I have full right to update the issues. Do you think I should update the masvs issue to reintegrate the matrix idea where we can link each category with a tool. Therefore simplifying it. I think it is too complicated in its current state for a school project

27. So the current issues are fine and not overly complicated you think?

28. Ok, so remind me the order in which I should do the issues. And when will I actually write which tool we chose for continuous integration on the masvs standard

29. So no documentation that explain the choice of each tool and how in integrated through masvs standard? Also which comments do you want me to add to robin's issues

30. Does the new issue has dependances to previous one? I guess masvs needs to have been done before?

31. Where do I add this?

    ```
    Started with: chore: enable secret scanning and push protection
    Related: #45, #82, docs: cyclonedx sbom per component
    ```

32. Ok. So everything is ready to start? (let's forget about the comments)

33. OK so I start by doing what

34. What is that for ?

    > Create the devsecops doc issue (5 minutes). Paste the body I wrote, then add Started with: #<secret scanning issue number> at the end. Do this first so the tool choice you're about to make is documented as part of the work.

    And I think I created the issue already:
    [Pasted: issue #109 "docs: devsecops pipeline, tool choices and masvs mapping" and the project board]

35. I don't understand this issue, what is sarif?
    [Pasted: body of issue #82 "ci: code scanning for go, dart and swift with sarif upload"]

36. What is githbub code scanning? Does it allows me to use multi tool through the ci but managed by github?

37. What do you mean by uploading the SARIF, do I need to upload a sarif for each tool? What does it do?

38. But will doing that not make the findings public ?

    > Uploading means sending that file from the runner to GitHub, using the `upload-sarif` step. GitHub then reads it and turns each finding into an alert attached to that commit and branch. That's the step that makes results appear in the Security tab and on PRs.

39. So what do you recommend

40. Ok, so what are the steps

41. So what will be code-scanning

42. Are all the tool I'll need in #82 already?

43. Ok, so #82 is for all the code scanning tools. How does it link to masvs categories?

44. Ok. So code-scanning.yaml will be for every tool not only code scanning?

45. Ok, so will there a yaml that link all the steps categories together (like code scanning)

46. Ok so for code-scanning there will be one single file, code-scanning.yaml and for each tool used in the file I need to upload the sarif. So sarif is a normalized json format for sast tools used to show an output of the sast result. So on each step the sarif is uploaded which allow to have a trace on the result of each step?

47. Ok, and are all the serif code scanning output for code scanning merged into one single serif at the end? What is the convention ?

48. And what is an alert in this context

49. Ok I see. So basically I just need to upload the serif of each code scanning step to github and then it will be automaticlaly made into alerts so I do not need to merge anything?

50. What should be the branch for the code scanning feature

51. What is the convention for github workflow testing

52. How is a group of job like this one called?
    [Pasted: the code-scanning.yml skeleton with the gosec job]

53. So for all code scanning I need one single file?

54. [Screenshot: the `.github` folder with scripts, semgrep and workflows]
    Why does claude code creates so many files

55. What is dart crypto for :
    [Attached: `dart-crypto.yaml`; pasted: `dart-crypto.dart`]

56. So what concretly are those for?

57. I don't understand. Give an example

58. Ok so it adds custom rules on functions that already exists?

59. And how concretly deos it check if for example the message is saved even tho the verifiyMessage func returned false

60. Ok, so dart-crypto.yaml is for pattern matching to detect security function that are used in a wrong way. but what is dart-crypto.yaml for?

61. Ok so this is a test file to verify if the custom rules correctly catch the misuages

62. Ok. And about the scripts, what do they do and are those necessary?
    [Pasted: `refuse-skipped-tests`, `sarif-from-json.sh`, `sarif-gate.sh`]

63. Why would a test being skipped

64. So this will analyse each serif for skipped tests?

65. And how will this skip every skipped test? It only work if the output is conventionnal right?

66. So this is only for dart? And what if a go test is skipped?

67. So this is the part that runs the go tests, does it compile also ? it is currently named ci.yaml but I think it should be renamed to something more precise:
    [Pasted: `ci.yml`]

68. Is build-and-test conventionnal?

69. But would it makes sense to add build and test in the same workflow

70. Can you add the build part :
    [Pasted: `ci.yml`]

71. How would the commit be for the change from ci.yml to build-and-test.yml

72. So this file is only for go building?

73. What is a registry server

74. Ok, and the other are built before being tested?

75. Wouldn't it be better to make it explicit?

76. What are the files sarif from json and sarif gate for

77. Ok and remind me the point of dar crypto dart and dart cyrpto yaml

78. And what do you think of the code scanning file:
    [Attached: the full `code-scanning.yaml`]

79. Can you explain each part of the pipeline it's quite complex

80. And explain each tool used

81. Should I add documentation already?

82. Also should the ci really only run on main ? Why not on other branches?

83. What does this do ?

    ```yaml
    on:
      schedule:
        - cron: "0 6 * * 1"
    ```

84. Ok so which updates do I need to add

85. So I guess I make 3 atomic commits scripts, dart, workflow ?

86. Remind me what is the crypto layer

87. So the crypto layer is mostly about authenticaiion, token exchanges, encryption

88. Ok which doc should I add then

89. What is otherwise for in masvs cntrol for. Also are some part of masvs not handled yet

90. Remove the otherwise column. Also how will we handle the part of the masvs that are not tested yet

91. So I also need to create masvs.md for this pr?

92. But then it should not be mentioned in the documentation

93. What does evidence means in this context:

    > To be completed as tools land (secret scanning, SBOM, binary analysis of the app). Evidence that does not come from a tool, and controls no tool covers, are tracked in the MASVS audit grid (#45).

94. Ok so I have only 1 doc page to push for this pr ?

95. [Screenshot: the github-advanced-security comment on the PR]
    What is that. And does it use my github tokens?

96. And is there a way to read the pipeline report after. And does it cancel for any vulnerabilities found?

97. [Screenshot: Code scanning page filtered on `branch:main`, empty]
    It's empty

98. [Screenshot: Code scanning page filtered on `branch:ci/code-scanning`, pointing to pull request #117]

99. [Screenshot: the Actions run "Ci/code scanning #3", all jobs green]
    And where do I go then

