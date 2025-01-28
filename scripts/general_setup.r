library(dplyr)
library(neuroCombat)

# Read the CSV files
realImageData = read.csv('realImageData.csv')
realPatientData = read.csv('realPatientData.csv')

# Display the first few rows of the data to verify
head(realImageData)
head(realPatientData)

# Create the model matrix
mod = model.matrix(~age + factor(sex), data=realPatientData)

# Transpose the image data
img = realImageData

# Harmonize the data using ComBat
harmonized = neuroCombat(dat=img, batch=realPatientData$dataset, mod=mod)

# Convert harmonized data to a data frame and add subject column
harmonizedData = as.data.frame(t(harmonized$dat.combat))
# Add subject_id from realPatientData to harmonizedData
harmonizedData$subject_id <- realPatientData$subject_id

# Merge the harmonized data with the patient data
postComBat <- left_join(realPatientData, harmonizedData, by = 'subject_id')

# write.csv(postComBat, 'harmonized_data.csv', row.names = FALSE)

# Fit a linear model
postRInsula <- lm(V1 ~ age + sex, data = postComBat)

# Display the summary of the ANOVA
summary(aov(postRInsula))

# Display the coefficients of the linear model
coef(postRInsula)[2:4]