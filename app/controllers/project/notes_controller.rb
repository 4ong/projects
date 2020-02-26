module Project
  class NotesController < ApplicationController
    def update
      puts params[:topic_id]
       @projects_task = ProjectsTask.where(["topic_id = ?",params[:topic_id]]).first
       #UPDATE
       ActiveRecord::Base.transaction do
        if @projects_task
          # @projects_task.update(task_params)
          #handle_locked()
          handle_deps(params[:note][:dry])
          handle_modified()
        else
          @topic = Topic.find(params[:topic_id])
          @projects_task = @topic.create_projects_task(task_params)
          handle_deps(params[:note][:dry])
          handle_modified()
        end
        raise ActiveRecord::Rollback if params[:note][:dry] == "true"
        end
      render json: { note: return_note }


#TODOrename params to fit model
#find topic find task
#task exists > update; else > create task
    end
    private
      def return_note
        #@projects_task = ProjectsTask.where(["topic_id = ?",params[:topic_id]]).first
        #todo feed modifed and derived from back into projects_task this means delete the above statement
        note = {
          'id' => @projects_task.topic_id,
          'begin' => @projects_task.begin,
          'end' => @projects_task.end,
          'duration' => @projects_task.duration,
          'locked' => @projects_task.locked,
          'depon' => @projects_task.depon,
          'depby' => @projects_task.depby,
          'messages' => @messages
        }
        return note
      end
      def handle_deps(dry)
        #byebug
#todo handle self dep
#WARN if :
#todo handle circular dep
#todo check if dependees finish before task begin date)
#todo check if dependers start after task end date)
#do dry runs and feed notes data back into composer
        ActiveRecord::Base.transaction(requires_new: true) do
          @projects_task.dependees=ProjectsTask.where(topic_id: params[:note][:depon])
          @projects_task.dependers=ProjectsTask.where(topic_id: params[:note][:depby])
          raise ActiveRecord::Rollback if dry == "true"
        end
      end
      def handle_modified
        messages = []
        @projects_task.assign_attributes(task_params)
        @projects_task.save
         if params[:note][:modified] == 'begin'
           #TODO deduplicate errors
           messages += @projects_task.set_end(params[:note][:end],false)
           messages += @projects_task.set_duration(params[:note][:duration])
           messages += @projects_task.set_begin(params[:note][:begin],false)
         elsif  params[:note][:modified] == 'duration'
           messages += @projects_task.set_end(params[:note][:end],false)
           messages += @projects_task.set_begin(params[:note][:begin],false)
           messages += @projects_task.set_duration(params[:note][:duration])
         elsif  params[:note][:modified] == 'end'
           messages += @projects_task.set_duration(params[:note][:duration])
           messages += @projects_task.set_begin(params[:note][:begin],false)
           messages += @projects_task.set_end(params[:note][:end],false)
         else #dependencies
           messages += @projects_task.set_end(params[:note][:end],false)
           messages += @projects_task.set_duration(params[:note][:duration])
           messages += @projects_task.set_begin(params[:note][:begin],false)
         end
         messages << {message_type:"test", message: "TEST#{@projects_task.topic_id} "}
         @messages = {}
         messages.each{ |m|
           unless m[:url].nil?
             @messages[m[:url]] = [] if @messages[m[:url]].nil?
             @messages[m[:url]] << m
           end
         }
         @messages.each{|k,t|
           t.uniq! {|m| m[:message]}
         }
      end
      def task_params
        params.require(:note).permit( :begin,:end,:duration,:locked,:disallow)
      end
  end
end
