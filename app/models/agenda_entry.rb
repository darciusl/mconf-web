class AgendaEntry < ActiveRecord::Base
  belongs_to :agenda

  has_one :attachment, :dependent => :destroy
  accepts_nested_attributes_for :attachment
  
  acts_as_stage
  
  #acts_as_content :reflection => :agenda
  
  # Minimum duration IN MINUTES of an agenda entry that is NOT excluded from recording 
  MINUTES_NOT_EXCLUDED =  30
  
  # Fill attachments event and space
  before_validation do |agenda_entry|
    if (agenda_entry.attachment.filename != nil) then
      agenda_entry.attachment.space  ||= agenda_entry.agenda.event.space
      agenda_entry.attachment.event  ||= agenda_entry.agenda.event
      agenda_entry.attachment.author ||= agenda_entry.agenda.event.author
    else
      agenda_entry.attachment = nil
    end
  end
  
  before_save do |entry|
    if entry.embedded_video.present?
      entry.video_thumbnail  = entry.get_background_from_embed
    end    
  end
  
  def validate
    # Check title presence
    if self.title.empty?
      errors.add_to_base(I18n.t('agenda.error.omit_title'))
    end
     
    # Check start and end times presence
    if self.start_time.nil? || self.end_time.nil? 
      errors.add_to_base(I18n.t('agenda.error.omit_date'))
    else
      # Check start time is previous to end time
      unless self.start_time <= self.end_time
        errors.add_to_base(I18n.t('agenda.error.dates'))
      end
       
      # Check the times don't overlap with existing entries 
      for entry in self.agenda.agenda_entries_for_day(self.start_time.day - self.agenda.event.start_date.day)
        if (self.id != entry.id) then
          if ((self.start_time >= entry.start_time) && (self.start_time < entry.end_time))
            errors.add_to_base(I18n.t('agenda.error.start_time_overlaps'))
          end
          if ((self.end_time > entry.start_time) && (self.end_time <= entry.end_time))
            errors.add_to_base(I18n.t('agenda.error.end_time_overlaps'))
          end
          if ((self.start_time < entry.start_time) && (self.end_time > entry.end_time))
            errors.add_to_base(I18n.t('agenda.error.overlaps'))
          end
          if ((self.start_time == entry.start_time) && (self.end_time == entry.end_time))
            errors.add_to_base(I18n.t('agenda.error.overlaps'))
          end          
        end   
      end
    end
  end
  
  def get_background_from_embed
    start_key = "image="   #this is the key where the background url starts
    end_key = "&amp;"      #this is the key where the background url ends
    start_index = embedded_video.index(start_key)
    if start_index
      temp_str = embedded_video[start_index+start_key.length..-1]
      endindex = temp_str.index(end_key)
      result = temp_str[0..endindex-1]
      return result
    else
      return nil
    end
  end
  
end