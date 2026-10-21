**Outcome.** Find out why typing `chongqizhiqian` does not let the user pick 重启之前 from the candidate list, and fix it so it does.

**Done means.**
- The cause is found and written under an **Evidence** heading (e.g. how the pinyin is split, how 重 is read: zhong/chong, whether 重启 and 之前 are in the dictionary, how whole-sentence candidates are built and ranked, whether the candidate list is cut off before it).
- After the fix, typing `chongqizhiqian` shows 重启之前 among the candidates and it can be selected.
- A unit test covers `chongqizhiqian` → 重启之前.

**Notes.**
- Related: A02-01 (whole-sentence pinyin), A03-02 / A03-04 (polyphonic readings), A04-02 (expanded candidate list).
- If the fix changes how candidates are ranked for other input, say so in the handoff.
