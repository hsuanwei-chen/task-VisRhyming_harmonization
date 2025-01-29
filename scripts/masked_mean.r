library(dplyr)
library(neuroCombat)
library(here)

# Set the working directory to the location of your script and CSV files
img_data <- here("data", "processed", "image_data.csv")
sub_data <- here("data", "processed", "subject_data.csv")

# Read the CSV files
img = t(read.csv('image_data.csv', header = FALSE))
subject_data = read.csv('subject_data.csv')

# Display the first few rows of the data to verify
head(img)
head(subject_data)

mod = model.matrix(~age + factor(sex), data=subject_data)

# Harmonize the data using ComBat
harmonized = neuroCombat(dat=img, batch=subject_data$dataset, mod=mod)

# Convert harmonized data to a data frame and add subject column
harmonizedData = as.data.frame(t(harmonized$dat.combat))
# Add subject_id from subject_data to harmonizedData
harmonizedData$subject <- subject_data$subject


img_data = as.data.frame(t(img))
img_data$subject <- subject_data$subject

# Merge the harmonized data with the patient data
postComBat <- left_join(subject_data, harmonizedData, by = 'subject')
preComBat <- left_join(subject_data, img_data, by = 'subject')

write.csv(postComBat, 'roi_harmonized_data.csv', row.names = FALSE)

print("Left Fusiform Pre ComBat")
postRInsula <- lm(V1 ~ age + sex + dataset, data = preComBat)
summary(postRInsula)

print("Left Fusiform Post ComBat")
postRInsula <- lm(V1 ~ age + sex + dataset, data = postComBat)
summary(postRInsula)

print("Left STG")
postRInsula <- lm(V2 ~ age + sex + dataset, data = preComBat)
summary(postRInsula)
postRInsula <- lm(V2 ~ age + sex + dataset, data = postComBat)
summary(postRInsula)

print("Left IFG")
postRInsula <- lm(V3 ~ age + sex + dataset, data = preComBat)
summary(postRInsula)
postRInsula <- lm(V3 ~ age + sex + dataset, data = postComBat)
summary(postRInsula)

library(ggplot2)
preComBat %>% 
  ggplot(aes(x = subject, y = V1, color = dataset)) +
  geom_point() +
  labs(y = "Mean Contrast in Left Fusiform")

postComBat %>% 
  arrange(dataset, subject) %>% 
  ggplot(aes(x = subject, y = V1, color = dataset)) +
  geom_point() +
  labs(y = "Mean Contrast in Left Fusiform")

preComBat %>% 
  ggplot(aes(x = subject, y = V2, color = dataset)) +
  geom_point() +
  labs(y = "Mean Contrast in Left STG")

postComBat %>% 
  arrange(dataset, subject) %>% 
  ggplot(aes(x = subject, y = V2, color = dataset)) +
  geom_point() + 
  labs(y = "Mean Contrast in Left STG")

preComBat %>% 
  ggplot(aes(x = subject, y = V3, color = dataset)) +
  geom_point() +
  scale_y_continuous(limits = c(-30, 10), breaks = seq(-30, 10, 5)) + 
  labs(title = "PreComBat", y = "Mean Contrast in Left IFG") +
  theme_bw()

postComBat %>% 
  arrange(dataset, subject) %>% 
  ggplot(aes(x = subject, y = V3, color = dataset)) +
  geom_point() + 
  scale_y_continuous(limits = c(-30, 10), breaks = seq(-30, 10, 5)) + 
  labs(title = "PostComBat", y = "Mean Contrast in Left IFG") +
  theme_bw()


