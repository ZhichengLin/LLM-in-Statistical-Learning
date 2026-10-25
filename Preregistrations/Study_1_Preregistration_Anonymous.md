# Study 1 preregistration anonymous review copy

Evaluating large language models (LLMs) on answering statistical questions and offering learning guidance

Original OSF registration date: **28 April 2025**. Original recorded timestamp: `2025-04-28T16:51:18.176358`.

Registration template: OSF Preregistration, version 3.

This is a transcription of the original preregistration for anonymous peer review, not a new registration. One author name in a response has been replaced with “[author name withheld]”. All other response wording is unchanged. Contributor metadata and direct links to the public original are omitted. The original OSF registration has not been modified.

Empty fields are shown as “No data” or “No files selected”, following OSF’s display.

## Description

This study compares the performance of different large language models (LLMs) in answering statistical questions, including p-values, confidence intervals, and statistical comparisons (if time and resources allow, we will attempt to collect and test other categories of statistical questions commonly mistaken by researchers/students, which would be analyzed in the same way). This evaluation would be helpful both in terms of 1) assessing the capability of these models and of 2) verifiying whether and how the models can be used to support student learning in statistics. These questions can be used to assess future models as well.

## Study Information

### Hypotheses

<p data-response="q2" data-index="0">The most important thing we want to establish is the general performance and stability of these models, to help us assess their potential in guiding statistical learning. The focus will be on descriptive statistics of model performance.<br />
<br />
Accuracy:<br />
- More advanced LLMs (defined as newer models and reasoning models) will achieve higher accuracy in solving statistical tasks compared to simpler models (defined as earlier models and non-reasoning models).<br />
- More advanced LLMs will demonstrate lower variability across repeated tests of the same question.<br />
- LLMs built with a “thinking” or “extended reasoning” mode (e.g., Claude Sonnet 3.7 “Extended thinking”; Grok 3 “Think”) will yield higher accuracy on average compared to non-thinking models/modes (e.g., Claude Sonnet 3.7; Grok 3).<br />
<br />
Guidance:<br />
Guidance from the top two models will be rated higher on average than the bottom two models, both by students and by instructors.</p>

## Design Plan

### Study type

<p data-response="q3" data-index="0">Observational Study - Data is collected from study subjects that are not randomly assigned to a treatment. This includes surveys, “natural experiments,” and regression discontinuity designs.</p>

### Blinding

<p data-response="q4" data-index="0">Personnel who analyze the data collected from the study are not aware of the treatment applied to any given group.</p>

### Is there any additional blinding in this study?

<p data-response="q5" data-empty="true">No data</p>

### Study design

<p data-response="q6.question" data-index="0">The study includes leading models across different platforms: ChatGPT (GPT-4o, o1, 4.5, o3, o4-mini, o4-mini-high), Gemini (2.0/2.5 Flash, 2.5 Pro), Claude (Sonnet 3.7 [Normal], 3.7 Sonnet [Extended thinking]), Grok (Grok 3, Grok 3 Think), Tongyi Qianwen 2.5, and DeepSeek-R1/V3. Each LLM is assessed individually. The exact models used are subject to change, based on the most current available models (both free and paid).<br />
<br />
Each LLM will complete three statistical tasks: p-value interpretation, confidence interval interpretation, and comparison of study results. <br />
<br />
The objective task is for all the models, where the LLM provides answers to the questions.<br />
<br />
The subjective task is for the selected top-two-performing models and bottom-two-performing models, where the LLM generates guidance to help users better understand the concepts. The reason for choosing the top two and bottom two models is to provide an assessment regarding the state-of-the-art models in helping students understand and learn statistical concepts, establishing a range.<br />
<br />
To maintain independence across responses, each task is conducted in a new session (chat window). Each objective task is iterated ten times per LLM (in a separate session). Each subjective task is iterated three times. <br />
<br />
Qualitative Evaluation<br />
After determining the top two models and bottom two models, we will perform a manual evaluation of their guidance by both students and instructors.<br />
<br />
Multiple student and instructor raters (≥4 in each group) will rate each explanation on four dimensions:<br />
1.	Statistical accuracy<br />
2.	Clarity &amp; structure<br />
3.	Conceptual depth<br />
4.	Pedagogical effectiveness/usefulness/helpfulness<br />
<br />
Ratings use a 1–7 scale, and we will compute average ratings and variance.</p>

<p data-response="q6.uploader" data-empty="true">No files selected</p>

### Randomization

<p data-response="q7" data-empty="true">No data</p>

## Sampling Plan

### Existing Data

<p data-response="q8" data-index="0">Registration prior to creation of data</p>

### Explanation of existing data

<p data-response="q9" data-index="0">I, [author name withheld], finalized the preregistration plan without access to the data while co-authors had began to run the study. So, when submitting this pre-registration plan, there are some data being collected without my access to it. </p>

### Data collection procedures

<p data-response="q10.question" data-index="0">Model outputs will be generated using a structured prompt sequence (see prompt under ‘Other’). Briefly, for each of the three statistical tasks, the LLMs will generate a direct True/False answer and (for top two and bottom two models) conceptual guidance. Each task will be repeated ten times per LLM in separate sessions to ensure response independence. </p>

<p data-response="q10.uploader" data-empty="true">No files selected</p>

### Sample size

<p data-response="q11" data-index="0">For the objective task: each model will complete three statistical tasks, and with m (e.g., eight) models, this results in a total output of: 3 tasks × 10 iterations per task × m models.<br />
<br />
For the subjective task: each model will complete three statistical tasks, and with four models, this results in a total output of: 3 tasks × 3 iterations per task × 4 models. <br />
<br />
Guidance rating will be conducted by a student group and an instructor group, each with at least four participants. </p>

### Sample size rationale

<p data-response="q12" data-index="0">Ten iterations per objective task (three per subjective task) per model to balance reliability and feasibility (previous research on LLMs has indicated that variation across iterations is generally low). </p>

### Stopping rule

<p data-response="q13" data-empty="true">No data</p>

## Variables

### Manipulated variables

<p data-response="q14.question" data-empty="true">No data</p>

<p data-response="q14.uploader" data-empty="true">No files selected</p>

### Measured variables

<p data-response="q15.question" data-index="0">odel answers (True/False): accuracy and standard deviation<br />
<br />
Model guidance: statistical accuracy, clarity &amp; structure, conceptual depth, and pedagogical effectiveness (1-7 scale for manual evaluation)<br />
</p>

<p data-response="q15.uploader" data-empty="true">No files selected</p>

### Indices

<p data-response="q16.question" data-empty="true">No data</p>

<p data-response="q16.uploader" data-empty="true">No files selected</p>

## Analysis Plan

### Statistical models

<p data-response="q17.question" data-index="0">Objective Accuracy Analysis<br />
1.	Dependent Variable<br />
o	Accuracy on each statistical question (binary: True/False). We will compute the proportion correct for each LLM–task combination over 10 repeated attempts.<br />
2.	Predictors (Fixed Effects)<br />
o	Model: A factor with levels corresponding to each LLM (e.g., GPT-4, Gemini 2.0 Flash, Claude Sonnet 3.7 Normal, etc.).<br />
o	Task: A factor with task types/levels (p-value interpretation, confidence interval interpretation, comparison of study results).<br />
o	Thinking Mode (optional): A binary factor (“Extended Reasoning” vs. “Normal Mode”).<br />
3.	Repeated Measures and Aggregation<br />
o	Each LLM is tested repeatedly (10 times per task), so we will aggregate the data to compute a single proportion correct for each LLM × task.<br />
o	We will then apply a (repeated-measures) ANOVA on these proportions, using a suitable transformation (logit or arcsine-square-root) if necessary to meet normality assumptions.<br />
4.	Planned Contrasts / Multiple Comparisons<br />
o	Key comparisons include: advanced LLMs vs. simpler LLMs, and thinking mode vs. normal mode.<br />
5.	Stability / Variability Analysis<br />
o	We will assess within-model consistency by computing the standard deviation of correctness across the 10 attempts for each model–task.<br />
<br />
Subjective Ratings Analysis<br />
1.	Dependent Variable<br />
o	We will average the four rating dimensions (statistical accuracy, clarity &amp; structure, conceptual depth, pedagogical effectiveness) into a single “Overall Quality” score (range 1–7).<br />
2.	Predictors (Fixed Effects)<br />
o	Model Group: Top 2 vs. Bottom 2 (identified from objective performance). This creates two levels (Top vs. Bottom).<br />
o	Rater Group: Student vs. Instructor (to examine any systematic differences in subjective ratings).<br />
3.	Random Effects<br />
o	Rater: Each explanation is rated by multiple student and instructor raters, so we include a random intercept for Rater.<br />
o	Iteration: Each of the four models (Top 2 vs. Bottom 2) produces an explanation across three repeated attempts; we can include a random intercept for Attempt (or Explanation ID) to account for repeated observations of the same model.<br />
4.	Proposed Model<br />
o	We will use a Linear Mixed-Effects Model on the single combined “Overall Quality” outcome. For example, in R using lme4:<br />
<br />
lmer(OverallQuality ~ ModelGroup * RaterGroup + (1|Rater) + (1|Attempt),<br />
     data = df_ratings)</p>

<p data-response="q17.uploader" data-empty="true">No files selected</p>

### Transformations

<p data-response="q18" data-empty="true">No data</p>

### Inference criteria

<p data-response="q19" data-empty="true">No data</p>

### Data exclusion

<p data-response="q20" data-empty="true">No data</p>

### Missing data

<p data-response="q21" data-empty="true">No data</p>

### Exploratory analysis

<p data-response="q22" data-empty="true">No data</p>

## Other

### Other

<p data-response="q23" data-index="0">Guidance Prompts:<br />
Prompt:<br />
Act as a knowledgeable and friendly statistics tutor. Please explain the concept of [p-values / confidence intervals / comparing p values from two studies] in a way that is extremely easy and memorable for someone new to statistics without sacrificing accuracy.<br />
<br />
1.	Start with a clear, plain-language definition of the concept.<br />
2.	Use at least one simple example (preferably from everyday life) to illustrate it.<br />
3.	Include at least one analogy that people might remember.<br />
4.	Point out common mistakes or misconceptions students often have about the concept, and clarify the correct interpretation.<br />
5.	Finish by giving a brief summary and mnemonic (a memory trick) to help them remember the essence of this concept.<br />
<br />
Answer Prompts:<br />
<br />
Questions on p-value (modified from source: Haller, H., &amp; Krauss, S. (2002). Misinterpretations of significance: A problem students share with their teachers. Methods of Psychological Research, 7(1), 1-20). Note that the original d.f. = 18 was incorrect; it should be 38. Also, the instruction was modified for LLMs.<br />
<br />
Suppose you have a treatment that you suspect may alter performance on a certain task. You compare the means of your control and experimental groups (say 20 subjects in each sample). Further, suppose you use a simple independent means t-test and your result is significant (t = 2.7, d.f. = 38, p = 0.01).<br />
<br />
Below is a list of six statements. For each statement, I want you to provide only “True” or “False” and nothing else. Do not add any explanations, commentary, or justification. If the statement logically follows from the premises above, mark ‘True.’ Otherwise, mark ‘False.’ Also note that several or none of the statements may be correct (between the population means).<br />
<br />
1)  	You have absolutely disproved the null hypothesis (that is, there is no difference between the population means). ☐ True ☐ False<br />
2)  	You have found the probability of the null hypothesis being true. ☐ True ☐ False<br />
3)  	You have absolutely proved your experimental hypothesis (that there is a difference between the population means). ☐ True ☐ False<br />
4)  	You can deduce the probability of the experimental hypothesis being true. ☐ True ☐ False<br />
5)  	You know, if you decide to reject the null hypothesis, the probability that you are making the wrong decision. ☐ True ☐ False<br />
6)  	You have a reliable experimental finding in the sense that if, hypothetically, the experiment were repeated a great number of times, you would obtain a significant result on 99% of occasions. ☐ True ☐ False<br />
<br />
Questions on confidence interval (CI; modified from source: <br />
Hoekstra, R., Morey, R. D., Rouder, J., and Wagenmakers, E.-J. (2014). Robust misinterpretation of confidence intervals. Psychon. Bull. Rev. 21, 1157–1164. doi: 10.3758/s13423-013-0572-3)<br />
<br />
You conduct an experiment, analyze the data, and report: "The 95% confidence interval for the mean ranges from 0.1 to 0.4."<br />
<br />
Below is a list of six statements. For each statement, I want you to provide only “True” or “False” and nothing else. Do not add any explanations, commentary, or justification. If the statement logically follows from the premises above, mark ‘True.’ Otherwise, mark ‘False.’ Also note that several or none of the statements may be correct (between the population means).<br />
<br />
1)  	The probability that the true mean is greater than 0 is at least 95%. ☐ True ☐ False<br />
2)  	The probability that the true mean equals 0 is smaller than 5%. ☐ True ☐ False<br />
3)  	The "null hypothesis" that the true mean equals 0 is likely to be incorrect. ☐ True ☐ False<br />
4)  	There is a 95% probability that the true mean lies between 0.1 and 0.4. ☐ True ☐ False<br />
5)  	We can be 95% confident that the true mean lies between 0.1 and 0.4. ☐ True ☐ False<br />
6)  	If we were to repeat the experiment over and over, then 95% of the time the true mean falls between 0.1 and 0.4. ☐ True ☐ False<br />
<br />
Questions on Comparing Results from Two Studies<br />
Two independent studies investigating the effectiveness of different treatments produced the following results:<br />
●	Study A: Effect estimate = 25, Standard Error = 10 (p &lt; 0.01)<br />
●	Study B: Effect estimate = 10, Standard Error = 10 (p &gt; 0.05)<br />
<br />
Below is a list of six statements. For each statement, I want you to provide only “True” or “False” and nothing else. Do not add any explanations, commentary, or justification. If the statement logically follows from the premises above, mark ‘True.’ Otherwise, mark ‘False.’ Also note that several or none of the statements may be correct (between the population means).<br />
<br />
1)  Because Study A is statistically significant but Study B is not, we can conclude that the effects differ significantly from each other in the two studies. ☐ True ☐ False<br />
2) The difference in the effect estimates between Study A and Study B might be due to random chance, so it is possible that the two treatments are equally effective. ☐ True ☐ False<br />
3) Study A provides stronger evidence for its treatment's effectiveness than Study B does for its treatment, but this doesn't necessarily mean the treatment in Study A is more effective than the one in Study B. ☐ True ☐ False<br />
4) Since the standard errors are equal in both studies, the difference in p-values can be solely attributed to the difference in effect estimates. ☐ True ☐ False<br />
5) If we combine the data from Study A and Study B into a single, larger study, the result would not be statistically significant. ☐ True ☐ False<br />
6) To determine if there's a statistically significant difference in the effectiveness of the treatments used in Study A and Study B, we would need to conduct a further statistical test that directly compares the results of the two studies. ☐ True ☐ False<br />
</p>
